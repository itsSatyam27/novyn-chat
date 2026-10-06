// WebRTC Service for Novyn Chat Call Management

// ── ICE / STUN / TURN configuration ──────────────────────────────────────────
// STUN-only works for ~80% of users. The TURN relays below handle the remaining
// ~20% who are behind symmetric NAT (corporate networks, some mobile carriers).
// Using Metered's free open relay as a fallback — no key needed for the open tier.
const ICE_SERVERS: RTCConfiguration = {
  iceServers: [
    // Google STUN (fast, public)
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
    { urls: 'stun:stun2.l.google.com:19302' },
    // Metered open STUN
    { urls: 'stun:stun.relay.metered.ca:80' },
    // Metered open TURN relays — required for symmetric NAT / corporate firewalls
    {
      urls: 'turn:global.relay.metered.ca:80',
      username: 'openrelayproject',
      credential: 'openrelayproject',
    },
    {
      urls: 'turn:global.relay.metered.ca:80?transport=tcp',
      username: 'openrelayproject',
      credential: 'openrelayproject',
    },
    {
      urls: 'turn:global.relay.metered.ca:443',
      username: 'openrelayproject',
      credential: 'openrelayproject',
    },
    {
      urls: 'turns:global.relay.metered.ca:443?transport=tcp',
      username: 'openrelayproject',
      credential: 'openrelayproject',
    },
  ],
  iceCandidatePoolSize: 10,
};

function normalizeIceServers(value: unknown): RTCIceServer[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry: any) => {
    const rawUrls: unknown[] = Array.isArray(entry?.urls) ? entry.urls : [entry?.urls];
    const urls: string[] = rawUrls
      .filter((url: unknown): url is string => typeof url === 'string')
      .map((url: string) => url.trim())
      .filter((url: string) => /^(stun|turn|turns):/i.test(url));
    if (!urls.length) return [];
    const server: RTCIceServer = { urls };
    if (typeof entry.username === 'string') server.username = entry.username;
    if (typeof entry.credential === 'string') server.credential = entry.credential;
    return [server];
  });
}

import {
  playIncomingRingtone,
  playOutgoingCallRing,
  stopAllCallAudio,
} from './audioManager';

export const playRingtone = playIncomingRingtone;
export const playCallRing = playOutgoingCallRing;
export const stopRingtone = stopAllCallAudio;

export function playCallEndSound() {
  try {
    const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(440, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(220, ctx.currentTime + 0.3);

    gain.gain.setValueAtTime(0.1, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.3);
    setTimeout(() => ctx.close(), 350);
  } catch {}
}

export class WebRTCManager {
  private pc: RTCPeerConnection | null = null;
  private localStream: MediaStream | null = null;
  private cameraTrack: MediaStreamTrack | null = null;
  private screenTrack: MediaStreamTrack | null = null;
  private remoteStream: MediaStream = new MediaStream();
  private pendingCandidates: RTCIceCandidateInit[] = [];
  private onRemoteStreamCallback: ((stream: MediaStream) => void) | null = null;
  private onLocalStreamCallback: ((stream: MediaStream) => void) | null = null;
  private onSignalCallback: ((signal: any) => void) | null = null;
  private onScreenShareEndedCallback: (() => void) | null = null;
  private isVideoCall = false;
  private rtcConfiguration: RTCConfiguration = ICE_SERVERS;
  private iceConfigurationPromise: Promise<void> | null = null;

  // A mobile uplink can easily queue a 1080p camera stream for seconds. Keep
  // interactive camera video within a real-time bitrate/framerate budget.
  private async optimizeVideoSender(sender: RTCRtpSender, isScreenShare = false) {
    try {
      const parameters = sender.getParameters();
      if (!parameters.encodings?.length) parameters.encodings = [{}];
      const encoding = parameters.encodings[0];
      encoding.maxBitrate = isScreenShare ? 2_000_000 : 1_200_000;
      encoding.maxFramerate = isScreenShare ? 20 : 24;
      await sender.setParameters(parameters);
    } catch (error) {
      // Older mobile WebViews may not support every sender parameter. Media
      // still works with the browser defaults in that case.
      console.debug('[WebRTC] Video sender optimisation unavailable:', error);
    }
  }

  constructor(
    onRemoteStream: (stream: MediaStream) => void,
    onSignal: (signal: any) => void,
    onLocalStream?: (stream: MediaStream) => void,
    onScreenShareEnded?: () => void
  ) {
    this.onRemoteStreamCallback = onRemoteStream;
    this.onSignalCallback = onSignal;
    this.onLocalStreamCallback = onLocalStream || null;
    this.onScreenShareEndedCallback = onScreenShareEnded || null;
  }

  public ensureIceServers(): Promise<void> {
    if (this.iceConfigurationPromise) return this.iceConfigurationPromise;

    this.iceConfigurationPromise = (async () => {
      const controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
      const timeout = controller ? window.setTimeout(() => controller.abort(), 3500) : null;
      try {
        const response = await fetch('/api/rtc/ice', {
          credentials: 'include',
          signal: controller?.signal,
        });
        const payload = await response.json().catch(() => null);
        const iceServers = normalizeIceServers(payload?.iceServers);
        if (response.ok && payload?.authenticated && iceServers.length) {
          this.rtcConfiguration = { iceServers, iceCandidatePoolSize: 2 };
          console.info('[WebRTC] Loaded authenticated ICE configuration.');
        } else {
          console.warn('[WebRTC] Authenticated ICE configuration unavailable; using fallback.');
        }
      } catch (err) {
        console.warn('[WebRTC] Could not load ICE configuration; using fallback.', err);
      } finally {
        if (timeout) window.clearTimeout(timeout);
      }
    })();

    return this.iceConfigurationPromise;
  }

  public async initLocalMedia(isVideo: boolean): Promise<MediaStream> {
    this.stopLocalMedia();
    this.isVideoCall = isVideo;

    // Try with video first (if video call), fall back to audio-only, then throw with real reason
    const audioConstraints = {
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
    };

    if (isVideo) {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          audio: audioConstraints,
          video: {
            width: { ideal: 960, max: 1280 },
            height: { ideal: 540, max: 720 },
            facingMode: 'user',
            frameRate: { ideal: 24, max: 30 },
          },
        });
        this.localStream = stream;
        this.cameraTrack = stream.getVideoTracks()[0] || null;
        if (this.onLocalStreamCallback) this.onLocalStreamCallback(stream);
        return stream;
      } catch (videoErr: any) {
        const name = videoErr?.name || 'UnknownError';
        // A denied/busy device must be reported as-is. Retrying immediately with
        // different constraints causes browsers to show a misleading second prompt.
        if (!['NotFoundError', 'OverconstrainedError'].includes(name)) {
          throw Object.assign(new Error(videoErr?.message || 'Camera or microphone access failed'), { name });
        }
        console.warn('[WebRTC] Camera unavailable, trying audio-only:', name, videoErr?.message);
      }
    }

    // Audio-only attempt
    try {
      const audioStream = await navigator.mediaDevices.getUserMedia({ audio: audioConstraints });
      this.localStream = audioStream;
      this.cameraTrack = null;
      if (this.onLocalStreamCallback) this.onLocalStreamCallback(audioStream);
      return audioStream;
    } catch (audioErr: any) {
      // Surface real error name so callers can show a useful message
      const name = audioErr?.name || 'UnknownError';
      const message = audioErr?.message || 'Unknown error';
      console.error('[WebRTC] Media access failed:', name, message);
      throw Object.assign(new Error(message), { name });
    }
  }

  public createPeerConnection(): RTCPeerConnection {
    if (this.pc) {
      this.pc.close();
      this.pc = null;
    }

    this.remoteStream = new MediaStream();
    this.pendingCandidates = [];

    const pc = new RTCPeerConnection(this.rtcConfiguration);
    this.pc = pc;

    pc.onicecandidate = (event) => {
      if (event.candidate && this.onSignalCallback) {
        this.onSignalCallback({ type: 'candidate', candidate: event.candidate.toJSON() });
      }
    };

    pc.oniceconnectionstatechange = () => {
      console.log('[WebRTC] ICE Connection State:', pc.iceConnectionState);
    };

    pc.ontrack = (event) => {
      console.log('[WebRTC] Track received:', event.track.kind, event.streams);
      if (event.streams && event.streams[0]) {
        this.remoteStream = event.streams[0];
      } else if (event.track) {
        // Ensure track is in our persistent remote stream
        if (!this.remoteStream.getTracks().some((t) => t.id === event.track.id)) {
          this.remoteStream.addTrack(event.track);
        }
      }

      if (this.onRemoteStreamCallback) {
        this.onRemoteStreamCallback(this.remoteStream);
      }
    };

    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => {
        const sender = pc.addTrack(track, this.localStream!);
        if (track.kind === 'video') void this.optimizeVideoSender(sender);
      });
    }

    // Keep a video receive m-line even when this side had to fall back to
    // audio-only media. Without it, the remote peer may be unable to send
    // video in a call where only one camera initialized successfully.
    if (!this.localStream?.getVideoTracks().length) {
      pc.addTransceiver('video', { direction: 'recvonly' });
    }

    return pc;
  }

  public async createOffer(): Promise<RTCSessionDescriptionInit> {
    if (!this.pc) this.createPeerConnection();
    const offer = await this.pc!.createOffer({
      offerToReceiveAudio: true,
      offerToReceiveVideo: true,
    });
    await this.pc!.setLocalDescription(offer);
    return offer;
  }

  public async handleOffer(offer: RTCSessionDescriptionInit): Promise<RTCSessionDescriptionInit> {
    if (!this.pc) this.createPeerConnection();
    await this.pc!.setRemoteDescription(new RTCSessionDescription(offer));
    await this.drainPendingCandidates();

    const answer = await this.pc!.createAnswer();
    await this.pc!.setLocalDescription(answer);
    return answer;
  }

  public async handleAnswer(answer: RTCSessionDescriptionInit) {
    if (this.pc) {
      await this.pc.setRemoteDescription(new RTCSessionDescription(answer));
      await this.drainPendingCandidates();
    }
  }

  public async handleCandidate(candidate: RTCIceCandidateInit) {
    if (!candidate) return;

    if (this.pc && this.pc.remoteDescription && this.pc.remoteDescription.type) {
      try {
        await this.pc.addIceCandidate(new RTCIceCandidate(candidate));
      } catch (err) {
        console.warn('Error adding ICE candidate directly:', err);
      }
    } else {
      // Queue candidate until setRemoteDescription completes
      this.pendingCandidates.push(candidate);
    }
  }

  private async drainPendingCandidates() {
    if (!this.pc || !this.pc.remoteDescription) return;
    while (this.pendingCandidates.length > 0) {
      const candidate = this.pendingCandidates.shift();
      if (candidate) {
        try {
          await this.pc.addIceCandidate(new RTCIceCandidate(candidate));
        } catch (err) {
          console.warn('Error adding queued ICE candidate:', err);
        }
      }
    }
  }

  public setAudioEnabled(enabled: boolean) {
    if (this.localStream) {
      this.localStream.getAudioTracks().forEach((track) => {
        track.enabled = enabled;
      });
    }
  }

  public setVideoEnabled(enabled: boolean) {
    if (this.localStream) {
      this.localStream.getVideoTracks().forEach((track) => {
        track.enabled = enabled;
      });
    }
  }

  public async toggleScreenShare(isSharing: boolean): Promise<boolean> {
    if (!this.pc || !this.localStream) return false;

    if (isSharing) {
      if (this.screenTrack) return true;
      try {
        const screenStream = await navigator.mediaDevices.getDisplayMedia({
          video: {
            frameRate: { ideal: 30, max: 60 },
          },
          audio: false,
        });
        const screenTrack = screenStream.getVideoTracks()[0];
        if (!screenTrack) return false;

        const videoSender = this.pc.getSenders().find(
          (sender) => sender.track?.kind === 'video'
        );
        // Screen sharing requires an existing video sender because replacing a
        // track is renegotiation-free. Adding a brand-new sender would require
        // a second offer/answer exchange that this call protocol does not do.
        if (!videoSender) {
          screenTrack.stop();
          console.warn('[WebRTC] Screen share unavailable without a video sender.');
          return false;
        }

        await videoSender.replaceTrack(screenTrack);
        void this.optimizeVideoSender(videoSender, true);
        this.screenTrack = screenTrack;

        // Keep the original camera track alive for restoration. The local
        // preview gets a separate stream containing audio + the screen track.
        const previewStream = new MediaStream([
          ...this.localStream.getAudioTracks(),
          screenTrack,
        ]);
        if (this.onLocalStreamCallback) this.onLocalStreamCallback(previewStream);

        screenTrack.contentHint = 'detail';
        screenTrack.onended = () => {
          void this.toggleScreenShare(false).then(() => {
            if (this.onScreenShareEndedCallback) this.onScreenShareEndedCallback();
          });
        };

        return true;
      } catch (err) {
        console.warn('Screen sharing cancelled or failed:', err);
        return false;
      }
    }

    try {
      const screenTrack = this.screenTrack;
      this.screenTrack = null;
      if (screenTrack) screenTrack.onended = null;

      if (this.cameraTrack && this.cameraTrack.readyState === 'live') {
        const videoSender = this.pc.getSenders().find(
          (sender) => sender.track?.kind === 'video'
        );
        if (videoSender) {
          await videoSender.replaceTrack(this.cameraTrack);
          void this.optimizeVideoSender(videoSender);
        }

        const previewStream = new MediaStream([
          ...this.localStream.getAudioTracks(),
          this.cameraTrack,
        ]);
        if (this.onLocalStreamCallback) this.onLocalStreamCallback(previewStream);
      } else if (screenTrack) {
        screenTrack.stop();
      }
    } catch (err) {
      console.warn('Could not restore camera after screen share:', err);
      return false;
    }

    return false;
  }

  public getLocalStream(): MediaStream | null {
    return this.localStream;
  }

  public getRemoteStream(): MediaStream {
    return this.remoteStream;
  }

  public stopLocalMedia() {
    if (this.screenTrack) {
      this.screenTrack.onended = null;
      this.screenTrack.stop();
      this.screenTrack = null;
    }
    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => {
        track.stop();
      });
      this.localStream = null;
    }
    this.cameraTrack = null;
  }

  public cleanup() {
    this.stopLocalMedia();
    this.pendingCandidates = [];
    if (this.pc) {
      this.pc.close();
      this.pc = null;
    }
    this.remoteStream = new MediaStream();
  }
}

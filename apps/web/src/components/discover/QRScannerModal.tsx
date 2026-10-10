import React, { useEffect, useRef, useState } from 'react';
import { Camera, Check, ImageUp, LoaderCircle, QrCode, X } from 'lucide-react';
import './qrScanner.css';

type DetectedCode = { rawValue: string };
type QRDetector = { detect: (source: HTMLVideoElement | ImageBitmap) => Promise<DetectedCode[]> };
type QRDetectorConstructor = new (options: { formats: string[] }) => QRDetector;

function getDetector(): QRDetector | null {
  const Detector = (window as typeof window & { BarcodeDetector?: QRDetectorConstructor }).BarcodeDetector;
  return Detector ? new Detector({ formats: ['qr_code'] }) : null;
}

function getNovynUsername(value: string): string | null {
  const raw = value.trim();
  if (/^@?[\w.-]{1,30}$/.test(raw)) return raw.replace(/^@/, '');

  try {
    const url = new URL(raw);
    const pathMatch = url.pathname.match(/^\/user\/([\w.-]{1,30})\/?$/i);
    const queryUsername = url.searchParams.get('user');
    const username = pathMatch?.[1] || queryUsername;
    return username && /^[\w.-]{1,30}$/.test(username) ? username : null;
  } catch {
    return null;
  }
}

export function QRScannerModal({ isOpen, onClose, onFoundUsername }: {
  isOpen: boolean;
  onClose: () => void;
  onFoundUsername: (username: string) => void;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const [status, setStatus] = useState('Point your camera at a Novyn QR code.');
  const [username, setUsername] = useState<string | null>(null);
  const [busy, setBusy] = useState(true);
  const [manualUsername, setManualUsername] = useState('');

  useEffect(() => {
    if (!isOpen) return;
    let active = true;
    let timer = 0;
    const stopCamera = () => {
      streamRef.current?.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    };
    const start = async () => {
      setUsername(null);
      setManualUsername('');
      setStatus('Point your camera at a Novyn QR code.');
      setBusy(true);
      const detector = getDetector();
      if (!detector) {
        setStatus('QR scanning is not supported by this browser. Upload a QR image or enter a username.');
        setBusy(false);
        return;
      }
      if (!navigator.mediaDevices?.getUserMedia) {
        setStatus('Camera access is unavailable. Upload a QR image or enter a username.');
        setBusy(false);
        return;
      }
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false });
        if (!active) {
          stream.getTracks().forEach((track) => track.stop());
          return;
        }
        streamRef.current = stream;
        const video = videoRef.current;
        if (!video) return;
        video.srcObject = stream;
        await video.play();
        setBusy(false);
        const scan = async () => {
          if (!active || !videoRef.current || videoRef.current.readyState < 2) {
            if (active) timer = window.setTimeout(scan, 250);
            return;
          }
          try {
            const [code] = await detector.detect(videoRef.current);
            if (code) {
              const found = getNovynUsername(code.rawValue);
              if (found) {
                setUsername(found);
                setStatus('Novyn profile found.');
                stopCamera();
                return;
              }
              setStatus('That QR code is not a Novyn profile. Keep scanning or enter a username.');
            }
          } catch {
            // Keep scanning while the camera provides its next frame.
          }
          if (active) timer = window.setTimeout(scan, 250);
        };
        void scan();
      } catch {
        setStatus('Camera permission was blocked. Upload a QR image or enter a username instead.');
        setBusy(false);
      }
    };

    void start();
    return () => {
      active = false;
      window.clearTimeout(timer);
      stopCamera();
    };
  }, [isOpen]);

  const scanImage = async (file?: File) => {
    if (!file) return;
    const detector = getDetector();
    if (!detector) {
      setStatus('QR image scanning is not supported by this browser. Enter the username instead.');
      return;
    }
    setBusy(true);
    try {
      const bitmap = await createImageBitmap(file);
      const [code] = await detector.detect(bitmap);
      bitmap.close();
      const found = code ? getNovynUsername(code.rawValue) : null;
      if (found) {
        setUsername(found);
        setStatus('Novyn profile found.');
        streamRef.current?.getTracks().forEach((track) => track.stop());
        streamRef.current = null;
      } else {
        setStatus('Could not find a Novyn profile QR code in that image.');
      }
    } catch {
      setStatus('Could not read that image. Try another QR image or enter a username.');
    } finally {
      setBusy(false);
    }
  };

  if (!isOpen) return null;
  return <div className="qr-scanner-backdrop" role="presentation" onClick={onClose}>
    <section className="qr-scanner-modal" role="dialog" aria-modal="true" aria-labelledby="qr-scanner-title" onClick={(event) => event.stopPropagation()}>
      <header className="qr-scanner-header">
        <span className="qr-scanner-icon"><QrCode size={20} /></span>
        <div><h2 id="qr-scanner-title">Scan a QR code</h2><p>Add a friend from their Novyn profile QR.</p></div>
        <button type="button" className="qr-scanner-close" onClick={onClose} aria-label="Close scanner"><X size={19} /></button>
      </header>

      <div className="qr-scanner-view" data-scanning={!username}>
        <video ref={videoRef} muted playsInline aria-label="QR scanner camera preview" />
        {!username && <div className="qr-scanner-frame" aria-hidden="true"><i /><i /><i /><i /></div>}
        {busy && <div className="qr-scanner-loading"><LoaderCircle size={22} /> Starting scanner…</div>}
        {username && <div className="qr-scanner-found"><Check size={18} /> Profile found</div>}
      </div>

      <p className="qr-scanner-status" role="status">{status}</p>
      {username && <div className="qr-scanner-result"><strong>@{username}</strong><button type="button" onClick={() => onFoundUsername(username)}>Send friend request</button></div>}

      <div className="qr-scanner-fallback">
        <label className="qr-scanner-upload"><ImageUp size={17} /> Upload QR image<input type="file" accept="image/*" onChange={(event) => void scanImage(event.target.files?.[0])} /></label>
        <span>or enter a username</span>
        <form onSubmit={(event) => { event.preventDefault(); const found = getNovynUsername(manualUsername); if (found) { setUsername(found); setStatus('Profile ready to add.'); } else setStatus('Enter a valid username.'); }}>
          <input value={manualUsername} onChange={(event) => setManualUsername(event.target.value)} placeholder="Username" aria-label="Friend username" />
          <button type="submit" disabled={!manualUsername.trim()}><Camera size={15} /> Find</button>
        </form>
      </div>
    </section>
  </div>;
}

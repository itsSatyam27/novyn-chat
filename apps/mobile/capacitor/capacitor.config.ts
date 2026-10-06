import { CapacitorConfig } from '@capacitor/cli';

const isDevServer = Boolean(process.env.CAP_SERVER_URL);
const config: CapacitorConfig = {
  appId: 'com.novyn.app',
  appName: 'Novyn',
  webDir: 'apps/web/dist',
  bundledWebRuntime: false,
  ...(isDevServer
    ? {
        server: {
          url: process.env.CAP_SERVER_URL,
          cleartext: process.env.CAP_CLEAR_TEXT === 'true'
        }
      }
    : {}),
  plugins: {
    StatusBar: {
      style: 'DARK',
      backgroundColor: '#F7F9FC',
      overlaysWebView: false
    },
    SplashScreen: {
      launchShowDuration: 900,
      launchAutoHide: true,
      backgroundColor: '#F7F9FC',
      showSpinner: false,
      androidScaleType: 'CENTER_CROP'
    },
    Camera: {},
    PushNotifications: {
      presentationOptions: ['badge', 'sound', 'alert', 'vibration'],
      android: {
        channelId: 'novyn-chat',
        channelName: 'Novyn Notifications',
        channelDescription: 'Chat notifications',
        importance: 4,
        visibility: 1
      }
    },
    Keyboard: {
      resize: 'native'
    }
  },
  android: {
    path: 'apps/mobile/capacitor/android',
    allowMixedContent: process.env.CAP_ALLOW_MIXED_CONTENT === 'true',
    permissions: [
      'CAMERA',
      'RECORD_AUDIO',
      'POST_NOTIFICATIONS'
    ]
  }
};

export default config;

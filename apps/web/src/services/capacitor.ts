import { Capacitor } from '@capacitor/core';
import { Haptics, ImpactStyle, NotificationType } from '@capacitor/haptics';
import { Camera, CameraResultType, CameraSource } from '@capacitor/camera';
import { Keyboard } from '@capacitor/keyboard';
import { StatusBar, Style } from '@capacitor/status-bar';

export const isNativeMobile = Capacitor.isNativePlatform();

export async function triggerHaptic(type: 'light' | 'medium' | 'heavy' | 'success' | 'warning' | 'error' = 'light') {
  if (typeof localStorage !== 'undefined' && localStorage.getItem('novyn_vibration') === 'false') return;
  if (!isNativeMobile) {
    if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      if (type === 'light') navigator.vibrate(10);
      else if (type === 'medium') navigator.vibrate(20);
      else if (type === 'heavy') navigator.vibrate(35);
      else if (type === 'success') navigator.vibrate([10, 30, 20]);
      else if (type === 'error') navigator.vibrate([30, 40, 30]);
    }
    return;
  }

  try {
    switch (type) {
      case 'light':
        await Haptics.impact({ style: ImpactStyle.Light });
        break;
      case 'medium':
        await Haptics.impact({ style: ImpactStyle.Medium });
        break;
      case 'heavy':
        await Haptics.impact({ style: ImpactStyle.Heavy });
        break;
      case 'success':
        await Haptics.notification({ type: NotificationType.Success });
        break;
      case 'warning':
        await Haptics.notification({ type: NotificationType.Warning });
        break;
      case 'error':
        await Haptics.notification({ type: NotificationType.Error });
        break;
    }
  } catch (err) {
    console.debug('Haptics failed:', err);
  }
}

export async function takeNativePhoto(): Promise<string | null> {
  if (!isNativeMobile) return null;
  try {
    const image = await Camera.getPhoto({
      quality: 90,
      allowEditing: false,
      resultType: CameraResultType.Uri,
      source: CameraSource.Prompt,
    });
    return image.webPath || null;
  } catch (err) {
    console.debug('Camera cancelled or failed:', err);
    return null;
  }
}

export async function setupMobileEnvironment() {
  if (!isNativeMobile) return;

  try {
    await StatusBar.setStyle({ style: Style.Dark });
    await StatusBar.setBackgroundColor({ color: '#e6f6f5' });
  } catch (err) {
    console.debug('StatusBar setup error:', err);
  }

  try {
    Keyboard.addListener('keyboardWillShow', (info) => {
      document.body.style.setProperty('--keyboard-height', `${info.keyboardHeight}px`);
    });
    Keyboard.addListener('keyboardWillHide', () => {
      document.body.style.setProperty('--keyboard-height', '0px');
    });
  } catch (err) {
    console.debug('Keyboard listeners setup error:', err);
  }
}

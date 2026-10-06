/* Google OAuth for Novyn Chat - Firebase Web SDK */

const firebaseConfig = {
  apiKey: "AIzaSyB1SjYr_LOS4oJ1sE4_Aws4Jg6faayvHT0",
  authDomain: "novyn-chat-app.firebaseapp.com",
  projectId: "novyn-chat-app",
  storageBucket: "novyn-chat-app.firebasestorage.app",
  messagingSenderId: "846944364575",
  appId: "1:846944364575:web:94fd318c693a337d498d2a",
};

function initializeFirebaseAuth() {
  if (!window.firebase || typeof window.firebase.initializeApp !== "function") {
    console.warn("Firebase SDK is not loaded.");
    return null;
  }
  if (!window.firebase.apps || window.firebase.apps.length === 0) {
    window.firebase.initializeApp(firebaseConfig);
  }
  return window.firebase.auth ? window.firebase.auth() : null;
}

function toGoogleAuthMessage(error) {
  const code = String(error?.code || "").trim();
  if (code === "auth/unauthorized-domain") {
    return `Google sign-in is blocked for this domain (${window.location.hostname}). Add it in Firebase Console > Authentication > Settings > Authorized domains.`;
  }
  if (code === "auth/popup-blocked") {
    return "Popup blocked by browser. Allow popups for this site and try Google sign-in again.";
  }
  if (code === "auth/popup-closed-by-user") {
    return "Google sign-in popup was closed before completing sign-in.";
  }
  if (code === "auth/cancelled-popup-request") {
    return "Another Google sign-in request is already in progress. Please try again.";
  }
  if (code === "auth/network-request-failed") {
    return "Network issue while contacting Google. Check your connection and retry.";
  }
  if (code === "auth/operation-not-supported-in-this-environment") {
    return "Google sign-in is not supported in this browser environment.";
  }
  return String(error?.message || "Google sign-in failed.");
}

function signInWithGoogle() {
  const auth = initializeFirebaseAuth();
  if (!auth) {
    return Promise.reject(new Error("Firebase auth unavailable."));
  }

  const provider = new window.firebase.auth.GoogleAuthProvider();
  return auth.signInWithPopup(provider)
    .then(async (result) => {
      const user = result.user;
      if (!user) {
        throw new Error("Google sign-in returned no user.");
      }
      const idToken = typeof user.getIdToken === "function"
        ? await user.getIdToken()
        : "";
      return {
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        idToken,
      };
    })
    .catch((error) => {
      console.error("Google sign-in failed", error);
      const mappedError = new Error(toGoogleAuthMessage(error));
      mappedError.code = String(error?.code || "");
      throw mappedError;
    });
}


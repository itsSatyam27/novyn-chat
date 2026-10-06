const socketAvailable = typeof io === "function";
const SOCKET_URL = window.location.origin.replace(/\/$/, "");
const socket = socketAvailable ? io(SOCKET_URL) : { on() {}, emit() {}, connected: false };
const authApi = window._novynAuth || null;

const loginCard         = document.getElementById("loginCard");
const chatLayout        = document.getElementById("chatLayout");
const loginForm         = document.getElementById("loginForm");
const usernameInput     = document.getElementById("usernameInput");
const passwordInput     = document.getElementById("passwordInput");
const usernameHint      = document.getElementById("usernameHint");
const usernameSuggestions = document.getElementById("usernameSuggestions");
const meName            = document.getElementById("meName");
const addFriendForm     = document.getElementById("addFriendForm");
const friendInput       = document.getElementById("friendInput");
const friendSuggestions = document.getElementById("friendSuggestions");
const chatLists         = document.querySelectorAll(".chat-list");
const requestList       = document.getElementById("requestList") || chatLists[0] || null;
const friendList        = document.getElementById("friendList") || chatLists[1] || null;
const sidebarSearch     = document.getElementById("sidebarSearchInput")
  || document.getElementById("sidebarSearch");
const activeFriendLabel = document.getElementById("activeFriendLabel");
const activeFriendPresenceLine = document.getElementById("activeFriendPresenceLine");
const activePresence    = document.getElementById("activePresence");
const activeFriendAvatar = document.getElementById("activeFriendAvatar");
const profilePanel      = document.getElementById("profilePanel");
const profilePanelAvatar = document.getElementById("profilePanelAvatar");
const profilePanelName  = document.getElementById("profilePanelName");
const profilePanelHandle = document.getElementById("profilePanelHandle");
const profilePanelStatus = document.getElementById("profilePanelStatus");
const profileStatMessages = document.getElementById("profileStatMessages") || document.getElementById("statMessages");
const profileStatMedia  = document.getElementById("profileStatMedia") || document.getElementById("statMedia");
const profileStatLinks  = document.getElementById("profileStatLinks") || document.getElementById("statLinks");
const profileStatFiles  = document.getElementById("profileStatFiles") || document.getElementById("statFiles");
const removeFriendBtn   = document.getElementById("removeFriendBtn");
const clearChatBtn      = document.getElementById("clearChatBtn");
const messagesEl        = document.getElementById("messages");
const meAvatar          = document.getElementById("meAvatar");
const infoPanel         = document.getElementById("infoPanel");
const infoPanelTitle    = document.getElementById("infoPanelTitle");
const infoPanelName     = document.getElementById("infoPanelName");
const infoPanelAvatar   = document.getElementById("infoPanelAvatar");
const infoPanelHandle   = document.getElementById("infoPanelHandle");
const infoPanelStatus   = document.getElementById("infoPanelStatus");
const infoTagsSection   = document.getElementById("infoTagsSection");
const groupInfoSection  = document.getElementById("groupInfoSection");
const groupMembersMeta  = document.getElementById("groupMembersMeta");
const groupMemberList   = document.getElementById("groupMemberList");
const messageForm       = document.getElementById("messageForm");
const messageInput      = document.getElementById("messageInput");
const attachFileBtn     = document.getElementById("attachFileBtn");
const attachFileInput   = document.getElementById("attachFileInput");
const cameraBtn         = document.getElementById("cameraBtn");
const cameraCaptureInput = document.getElementById("cameraCaptureInput");
const toast             = document.getElementById("toast");
const storiesRow        = document.getElementById("storiesRow");
const storyFriendList   = document.getElementById("storyFriendList");
const typingIndicator   = document.getElementById("typingIndicator");
const typingAvatar      = document.getElementById("typingAvatar");
const typingText        = document.getElementById("typingText");
const speakingIndicator = document.getElementById("speakingIndicator");
const speakingAvatar    = document.getElementById("speakingAvatar");
const speakingText      = document.getElementById("speakingText");
const connectionLabel   = document.getElementById("connectionLabel");
const networkPill       = document.getElementById("networkPill");
const retryFailedBtn    = document.getElementById("retryFailedBtn");
const requestCount      = document.getElementById("requestCount");
const friendCount       = document.getElementById("friendCount");
const onlineCount       = document.getElementById("onlineCount");
const contactsRequestsBtn = document.getElementById("contactsRequestsBtn");
const contactsRequestsPanel = document.getElementById("contactsRequestsPanel");
const contactsRequestsBadge = document.getElementById("contactsRequestsBadge");
const discoverPanel    = document.getElementById("discoverPanel");
const discoverList     = document.getElementById("discoverList");
const discoverEmpty    = document.getElementById("discoverEmpty");
const sendButton        = messageForm ? messageForm.querySelector('button[type="submit"]') : null;
const voiceBtn          = document.getElementById("voiceBtn");
const voiceStatus       = document.getElementById("voiceStatus");
const voiceTimer        = document.getElementById("voiceTimer");
const voiceLabel        = document.getElementById("voiceLabel");
const voiceCancelBtn    = document.getElementById("voiceCancelBtn");
const voiceStopBtn      = document.getElementById("voiceStopBtn");
const voiceProgress     = document.getElementById("voiceProgress");
const voiceProgressBar  = document.getElementById("voiceProgressBar");
const voiceProgressText = document.getElementById("voiceProgressText");
const messageSearchToggle = document.getElementById("messageSearchToggle");
const messageSearchPanel = document.getElementById("messageSearchPanel");
const messageSearchInput = document.getElementById("messageSearchInput");
const messageSearchClear = document.getElementById("messageSearchClear");
const messageSearchPrev  = document.getElementById("messageSearchPrev");
const messageSearchNext  = document.getElementById("messageSearchNext");
const messageSearchCount = document.getElementById("messageSearchCount");
const messageSearchScope = document.getElementById("messageSearchScope");
const messageSearchFilter = document.getElementById("messageSearchFilter");
const globalSearchResults = document.getElementById("globalSearchResults");
const infoToggleBtn      = document.getElementById("infoToggleBtn");
const callButton       = document.querySelector(".chat-header-actions .call-btn");
const videoButton      = document.querySelector(".chat-header-actions .video-btn");
const profileCallBtn   = document.querySelector(".profile-action-btn[data-action='call']");
const profileVideoBtn  = document.querySelector(".profile-action-btn[data-action='video']");
const infoCallBtn      = document.getElementById("infoCallBtn");
const infoMuteBtn      = document.getElementById("infoMuteBtn");
const infoBlockBtn     = document.getElementById("infoBlockBtn");
const infoReportBtn    = document.getElementById("infoReportBtn");
const infoAddMembersBtn = document.getElementById("infoAddMembersBtn");
const infoMediaGrid    = document.getElementById("infoMediaGrid");
const callModal        = document.getElementById("callModal");
const statusViewerModal = document.getElementById("statusViewerModal");
const statusViewerBackdrop = document.getElementById("statusViewerBackdrop");
const statusViewerProgressBar = document.getElementById("statusViewerProgressBar");
const statusViewerAvatar = document.getElementById("statusViewerAvatar");
const statusViewerName = document.getElementById("statusViewerName");
const statusViewerTime = document.getElementById("statusViewerTime");
const statusViewerText = document.getElementById("statusViewerText");
const statusViewerCloseBtn = document.getElementById("statusViewerCloseBtn");
const statusViewerEditBtn = document.getElementById("statusViewerEditBtn");
const statusViewerPrevBtn = document.getElementById("statusViewerPrev");
const statusViewerNextBtn = document.getElementById("statusViewerNext");
const callBadge        = document.getElementById("callBadge");
const callAvatar       = document.getElementById("callAvatar");
const callMiniAvatar   = document.getElementById("callMiniAvatar");
const callPeerName     = document.getElementById("callPeerName");
const callStatusText   = document.getElementById("callStatusText");
const callDurationText = document.getElementById("callDuration");
const callMuteBtn      = document.getElementById("callMuteBtn");
const callSpeakerBtn   = document.getElementById("callSpeakerBtn");
const callCameraBtn    = document.getElementById("callCameraBtn");
const callFlipBtn      = document.getElementById("callFlipBtn");
const callAcceptBtn    = document.getElementById("callAcceptBtn");
const callRejectBtn    = document.getElementById("callRejectBtn");
const callHangupBtn    = document.getElementById("callHangupBtn");
const callMinimizeBtn  = document.getElementById("callMinimizeBtn");
const callRemoteAudio  = document.getElementById("callRemoteAudio");
const callRemoteVideo  = document.getElementById("callRemoteVideo");
const callLocalVideo   = document.getElementById("callLocalVideo");
const callMini         = document.getElementById("callMini");
const callMiniName     = document.getElementById("callMiniName");
const callMiniStatus   = document.getElementById("callMiniStatus");
const callMiniTime     = document.getElementById("callMiniTime");
const callMiniEnd      = document.getElementById("callMiniEnd");
const callLogList      = document.getElementById("callLogList");
const callHistoryList  = document.getElementById("callHistoryList");
const navRailButtons   = Array.from(document.querySelectorAll(".tab-btn[data-rail], .nav-btn[data-rail]"));
const bottomTabBar     = document.querySelector(".bottom-tab-bar");
const navSettingsBtn   = document.getElementById("navSettingsBtn");
const settingsPanel    = document.getElementById("settingsPanel");
const settingsCloseBtn = document.getElementById("settingsCloseBtn");
const settingsAvatar   = document.getElementById("settingsAvatar");
const settingsProfileName = document.getElementById("settingsProfileName");
const settingsProfileHandle = document.getElementById("settingsProfileHandle");
const settingsPresenceLine = document.getElementById("settingsPresenceLine");
const settingsPresenceText = document.getElementById("settingsPresenceText");
const statusPillButtons = Array.from(document.querySelectorAll(".status-pill[data-status]"));
const createGroupBtn   = document.getElementById("createGroupBtn");
const chatQuickMenuBtn = document.getElementById("chatQuickMenuBtn");
const chatQuickMenu    = document.getElementById("chatQuickMenu");
const chatQuickClearItem = chatQuickMenu ? chatQuickMenu.querySelector('[data-quick-action="clear-chat"]') : null;
const chatCategoryButtons = Array.from(document.querySelectorAll(".chat-category-btn"));
const chatFilterCountAll = document.getElementById("chatFilterCountAll");
const chatFilterCountGroups = document.getElementById("chatFilterCountGroups");
const chatFilterCountBlocked = document.getElementById("chatFilterCountBlocked");
const chatFilterCountUnread = document.getElementById("chatFilterCountUnread");
const messageViewMeta  = document.getElementById("messageViewMeta");
const sidebarBrand = document.querySelector(".app-brand");
const sidebarTopActions = document.querySelector(".sidebar-top-actions");
const callFilterButtons = Array.from(document.querySelectorAll("[data-call-filter]"));
const mobileSidebar     = document.getElementById("mobileSidebar");
const mobileChat        = document.getElementById("mobileChat");
const mobBackBtn        = document.getElementById("mobBackBtn");
const SESSION_KEY       = "novyn-session";
const REMEMBER_KEY      = "novyn-remember";
const MESSAGE_DRAFTS_KEY = "novyn-message-drafts";
const PENDING_STATE_KEY = "novyn-pending-v2";
const LOGIN_PATH        = "/login.html";
const isDashboardPage   = Boolean(chatLayout) && !document.body.classList.contains("auth-page");
// Mobile layout breakpoint (desktop enhancements activate above this).
const MOBILE_BP         = 979;
const INCOMING_CALLS_ENABLED = true;
const GLOBAL_SEARCH_MIN_QUERY_LENGTH = 2;
const PRESENCE_IDLE_AWAY_MS = 5 * 60 * 1000;
const PRESENCE_HIDDEN_AWAY_MS = 45 * 1000;
const PRESENCE_ACTIVITY_THROTTLE_MS = 1500;
const scheduleBtn       = document.getElementById("scheduleBtn");
const scheduleMenu      = document.getElementById("scheduleMenu");
const scheduleDateInput = document.getElementById("scheduleDateInput");
const scheduleTimeInput = document.getElementById("scheduleTimeInput");
const schedulePreviewText = document.getElementById("schedulePreviewText");
const scheduleMenuCloseBtn = document.getElementById("scheduleMenuCloseBtn");
const scheduleMenuCancelBtn = document.getElementById("scheduleMenuCancelBtn");
const scheduleMenuConfirmBtn = document.getElementById("scheduleMenuConfirmBtn");
const schedulePresetButtons = Array.from(document.querySelectorAll("[data-schedule-minutes]"));
const scheduledPanel    = document.getElementById("scheduledPanel");
const scheduledPanelToggleBtn = document.getElementById("scheduledPanelToggleBtn");
const scheduledPanelTitle = document.getElementById("scheduledPanelTitle");
const scheduledList     = document.getElementById("scheduledList");
const scheduledEmpty    = document.getElementById("scheduledEmpty");
const CSRF_COOKIE_NAME = "novyn_csrf";
const CSRF_HEADER_NAME = "x-novyn-csrf";

let me           = "";
let activeFriend = "";
let activeChatKind = "friend";
let friends      = [];
let hasGreeted   = false;
let requests     = [];
let discoverUsers = [];
let replyTo      = null;
let searchPanelOpen = false;
let friendSearchQuery = "";
let sidebarView = "messages";
let messageListFilter = "all";
let settingsOpen = false;
let callFilter = "all";
let logoutInProgress = false;
if (sidebarSearch) {
  sidebarSearch.value = "";
  sidebarSearch.setAttribute("value", "");
  friendSearchQuery = "";
}
window.addEventListener("pageshow", () => {
  if (!sidebarSearch) return;
  sidebarSearch.value = "";
  sidebarSearch.setAttribute("value", "");
  friendSearchQuery = "";
  renderRequests();
  renderFriends();
  renderCallHistory();
  renderDiscover();
}, { passive: true });

let _clearAttempts = 0;
const _clearSearch = setInterval(() => {
  if (sidebarSearch && sidebarSearch.value) {
    sidebarSearch.value = "";
    sidebarSearch.setAttribute("value", "");
    friendSearchQuery = "";
    renderFriends();
  }
  if (++_clearAttempts >= 10) clearInterval(_clearSearch);
}, 50);
const sidebarBrandHTML = sidebarBrand ? sidebarBrand.innerHTML : "";
const searchState = {
  hits: [],
  index: -1,
  query: "",
};
const globalSearchState = {
  requestId: 0,
  query: "",
  filter: "all",
  results: [],
  loading: false,
  timer: null,
};
const safetyState = {
  blocked: new Set(),
  muted: new Set(),
};
const scheduledState = {
  byChat: new Map(),
};
const groupInfoState = {
  byId: new Map(),
  requestedAt: new Map(),
};
const statusViewerState = {
  entries: [],
  index: -1,
  startedAt: 0,
  timerId: null,
};
let scheduledPanelExpanded = false;
let pendingMessageFocus = { friendKey: "", messageId: "", kind: "friend" };
const friendSuggestState = {
  timer: null,
  lastQuery: "",
};
let myProfile    = { avatarId: "", displayName: "", age: "", gender: "", bio: "", email: "" };
let conversationMessages = [];
let pendingUnreadJump = { friendKey: "", count: 0 };
let lastInfoPanelFriendKey = "";
let messageWindowStart = 0;
let messageWindowEnd = 0;
let historyRenderWarningShown = false;
let loadOlderBtn = null;
let loadOlderInProgress = false;
const MAX_VISIBLE_MESSAGES = 100;
const MESSAGE_WINDOW_PAGE = 100;
const INFO_MEDIA_PREVIEW_LIMIT = 120;
const LOAD_OLDER_SHOW_TOP_THRESHOLD = 80;
const PENDING_RETRY_BASE_MS = 2500;
const PENDING_RETRY_MAX_MS = 20000;
const PENDING_RETRY_TICK_MS = 1500;
const PENDING_RETRY_MAX_ATTEMPTS = 8;
const COMPOSER_MAX_MESSAGE_LENGTH = Number.isFinite(Number(messageInput?.maxLength))
  && Number(messageInput?.maxLength) > 0
  ? Math.floor(Number(messageInput.maxLength))
  : 1000;
const MESSAGE_DRAFT_MAX_LENGTH = COMPOSER_MAX_MESSAGE_LENGTH;
const ATTACHMENT_MAX_SIZE_BYTES = 15 * 1024 * 1024;
const pendingQueue = [];
const pendingQueueByTempId = new Map();
const pendingByTempId = new Map();
let messageDrafts = new Map();
let loadedDraftOwnerKey = "";
let loadedPendingOwnerKey = "";
let pendingStatePersistTimer = null;
let suppressPendingStatePersist = 0;
let networkStateLabel = "";
let networkStateMode = "";
let myPresenceMode = "online";
let manualPresenceMode = "online";
let pendingPresenceSyncMode = "";
let presenceSyncTimer = null;
let nextPresenceSyncRetryAt = 0;
let presenceIdleTimer = null;
let presenceHiddenTimer = null;
let lastPresenceActivityEventAt = 0;
let presenceAutoAwayActive = false;
let restoredPendingToastShown = false;
window._novynProfile = myProfile;
let novynLabsState = {
  branchByChat: {},
  branchFilterByChat: {},
  defaultIntentByChat: {},
  intentFilterByChat: {},
  trustByChat: {},
  moodByChat: {},
  contextAwareDelivery: true,
  lastViewedByChat: {},
};

const localTyping = {
  active:    false,
  target:    "",
  kind:      "friend",
  timeoutId: null,
};
const scrollState = {
  pinnedToBottom: true,
};
let suppressMessageViewportHandlers = 0;
const attachmentUploadState = {
  active: false,
  pendingTempId: "",
  target: "",
};
const cameraCaptureState = {
  stream: null,
  facingMode: "environment",
  opening: false,
};
const EMPTY_CONVERSATION_HINT = "Choose a conversation to start messaging.";
const DELETED_MESSAGE_TEXT = "This message was deleted.";
const CALL_LOG_PREFIX = "__call_log__:";
const CALL_HISTORY_KEY = "novyn-call-history";
const MAX_CALL_HISTORY = 200;
const MAX_UPDATES_STRIP_ITEMS = 12;
const MY_STATUS_STORAGE_PREFIX = "novyn-my-status";
const STATUS_EXPIRY_MS = 24 * 60 * 60 * 1000;
const STATUS_SLIDE_MS = 5500;
const BAD_CALL_STATUSES = new Set(["cancelled", "declined", "missed", "busy", "unavailable", "blocked"]);
const MISSED_CALL_FILTER_STATUSES = new Set(["missed", "declined", "busy", "unavailable", "cancelled"]);
const ATTACHMENT_EXT_PATTERN = /\.(?:png|jpe?g|gif|webp|bmp|svg|mp4|mov|webm|mp3|wav|ogg|m4a|aac|pdf|txt|csv|zip|rar|7z|docx?|pptx?|xlsx?)(?:[?#].*)?$/i;
const IMAGE_ATTACHMENT_EXT_PATTERN = /\.(?:png|jpe?g|gif|webp|bmp|svg)(?:[?#].*)?$/i;
const NOVYN_LABS_STORAGE_KEY = "novyn-labs-v1";
const NOVYN_META_PREFIX = "[[novyn:";
const NOVYN_META_SUFFIX = "]]";
const NOVYN_INTENT_TYPES = new Set(["question", "decision", "action", "fyi", "urgent"]);
const NOVYN_MOOD_TYPES = new Set(["auto", "calm", "focus", "hype", "off"]);

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Utilities Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

function normalizeName(value) {
  return String(value || "").trim().toLowerCase();
}

function normalizeSearchText(value) {
  return String(value || "").trim().toLowerCase();
}

function normalizeChatKind(value) {
  return String(value || "").trim().toLowerCase() === "group" ? "group" : "friend";
}

function normalizePresenceMode(value, fallback = "online") {
  const mode = String(value || "").trim().toLowerCase();
  if (mode === "online" || mode === "away" || mode === "busy" || mode === "offline") {
    return mode;
  }
  const fallbackMode = String(fallback || "").trim().toLowerCase();
  if (fallbackMode === "online" || fallbackMode === "away" || fallbackMode === "busy" || fallbackMode === "offline") {
    return fallbackMode;
  }
  return "online";
}

function normalizeLabsBranch(value) {
  const raw = String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return raw.slice(0, 32);
}

function normalizeLabsIntent(value) {
  const intent = String(value || "").trim().toLowerCase();
  return NOVYN_INTENT_TYPES.has(intent) ? intent : "";
}

function normalizeLabsMood(value) {
  const mood = String(value || "").trim().toLowerCase();
  return NOVYN_MOOD_TYPES.has(mood) ? mood : "auto";
}

function getLabsChatKey(username = activeFriend, kind = activeChatKind) {
  const key = normalizeName(username);
  if (!key) return "";
  return `${normalizeChatKind(kind)}:${key}`;
}

function loadNovynLabsState() {
  try {
    const raw = localStorage.getItem(NOVYN_LABS_STORAGE_KEY);
    if (!raw) return;
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return;
    novynLabsState = {
      ...novynLabsState,
      branchByChat: parsed.branchByChat && typeof parsed.branchByChat === "object" ? parsed.branchByChat : {},
      branchFilterByChat: parsed.branchFilterByChat && typeof parsed.branchFilterByChat === "object" ? parsed.branchFilterByChat : {},
      defaultIntentByChat: parsed.defaultIntentByChat && typeof parsed.defaultIntentByChat === "object" ? parsed.defaultIntentByChat : {},
      intentFilterByChat: parsed.intentFilterByChat && typeof parsed.intentFilterByChat === "object" ? parsed.intentFilterByChat : {},
      trustByChat: parsed.trustByChat && typeof parsed.trustByChat === "object" ? parsed.trustByChat : {},
      moodByChat: parsed.moodByChat && typeof parsed.moodByChat === "object" ? parsed.moodByChat : {},
      contextAwareDelivery: parsed.contextAwareDelivery !== false,
      lastViewedByChat: parsed.lastViewedByChat && typeof parsed.lastViewedByChat === "object" ? parsed.lastViewedByChat : {},
    };
  } catch (_) {
    // Ignore malformed labs state.
  }
}

function persistNovynLabsState() {
  try {
    localStorage.setItem(NOVYN_LABS_STORAGE_KEY, JSON.stringify(novynLabsState));
  } catch (_) {
    // Ignore storage failures.
  }
}

function getLabsBranchForChat(chatKey = getLabsChatKey()) {
  if (!chatKey) return "";
  return normalizeLabsBranch(novynLabsState.branchByChat?.[chatKey] || "");
}

function getLabsBranchFilterForChat(chatKey = getLabsChatKey()) {
  if (!chatKey) return "";
  const filter = normalizeLabsBranch(novynLabsState.branchFilterByChat?.[chatKey] || "");
  return filter || "all";
}

function getLabsDefaultIntentForChat(chatKey = getLabsChatKey()) {
  if (!chatKey) return "";
  return normalizeLabsIntent(novynLabsState.defaultIntentByChat?.[chatKey] || "");
}

function getLabsIntentFilterForChat(chatKey = getLabsChatKey()) {
  if (!chatKey) return "all";
  const filter = normalizeLabsIntent(novynLabsState.intentFilterByChat?.[chatKey] || "");
  return filter || "all";
}

function getLabsTrustModeForChat(chatKey = getLabsChatKey()) {
  if (!chatKey) return false;
  return Boolean(novynLabsState.trustByChat?.[chatKey]);
}

function getLabsMoodForChat(chatKey = getLabsChatKey()) {
  if (!chatKey) return "auto";
  return normalizeLabsMood(novynLabsState.moodByChat?.[chatKey] || "auto");
}

function setLabsBranchForChat(branch, chatKey = getLabsChatKey()) {
  if (!chatKey) return;
  const nextBranch = normalizeLabsBranch(branch);
  if (nextBranch) {
    novynLabsState.branchByChat[chatKey] = nextBranch;
  } else {
    delete novynLabsState.branchByChat[chatKey];
  }
  persistNovynLabsState();
}

function setLabsBranchFilterForChat(branchFilter, chatKey = getLabsChatKey()) {
  if (!chatKey) return;
  const normalized = String(branchFilter || "").trim().toLowerCase();
  if (!normalized || normalized === "all") {
    novynLabsState.branchFilterByChat[chatKey] = "all";
  } else {
    novynLabsState.branchFilterByChat[chatKey] = normalizeLabsBranch(normalized);
  }
  persistNovynLabsState();
}

function setLabsDefaultIntentForChat(intent, chatKey = getLabsChatKey()) {
  if (!chatKey) return;
  const normalized = normalizeLabsIntent(intent);
  if (normalized) {
    novynLabsState.defaultIntentByChat[chatKey] = normalized;
  } else {
    delete novynLabsState.defaultIntentByChat[chatKey];
  }
  persistNovynLabsState();
}

function setLabsIntentFilterForChat(intentFilter, chatKey = getLabsChatKey()) {
  if (!chatKey) return;
  const normalized = normalizeLabsIntent(intentFilter);
  if (normalized) {
    novynLabsState.intentFilterByChat[chatKey] = normalized;
  } else {
    novynLabsState.intentFilterByChat[chatKey] = "all";
  }
  persistNovynLabsState();
}

function setLabsTrustModeForChat(enabled, chatKey = getLabsChatKey()) {
  if (!chatKey) return;
  if (enabled) {
    novynLabsState.trustByChat[chatKey] = true;
  } else {
    delete novynLabsState.trustByChat[chatKey];
  }
  persistNovynLabsState();
}

function setLabsMoodForChat(mood, chatKey = getLabsChatKey()) {
  if (!chatKey) return;
  novynLabsState.moodByChat[chatKey] = normalizeLabsMood(mood);
  persistNovynLabsState();
}

function updateLabsLastViewedForChat(chatKey = getLabsChatKey(), iso = new Date().toISOString()) {
  if (!chatKey) return;
  novynLabsState.lastViewedByChat[chatKey] = String(iso || new Date().toISOString());
  persistNovynLabsState();
}

function getLabsLastViewedForChat(chatKey = getLabsChatKey()) {
  if (!chatKey) return "";
  return String(novynLabsState.lastViewedByChat?.[chatKey] || "");
}

function extractLabsMetaFromText(rawText) {
  const text = String(rawText || "");
  const result = {
    text,
    meta: {},
  };
  if (!text.startsWith(NOVYN_META_PREFIX)) return result;
  const closeIndex = text.indexOf(NOVYN_META_SUFFIX);
  if (closeIndex <= NOVYN_META_PREFIX.length) return result;
  const rawMeta = text.slice(NOVYN_META_PREFIX.length, closeIndex);
  const nextText = text.slice(closeIndex + NOVYN_META_SUFFIX.length).trimStart();
  const parsed = {};
  rawMeta.split(";").forEach((chunk) => {
    const piece = String(chunk || "").trim();
    if (!piece || !piece.includes("=")) return;
    const [keyRaw, ...rest] = piece.split("=");
    const key = String(keyRaw || "").trim().toLowerCase();
    const value = rest.join("=").trim();
    if (!key || !value) return;
    if (key === "branch") {
      const branch = normalizeLabsBranch(value);
      if (branch) parsed.branch = branch;
      return;
    }
    if (key === "intent") {
      const intent = normalizeLabsIntent(value);
      if (intent) parsed.intent = intent;
      return;
    }
    if (key === "sensitive") {
      parsed.sensitive = value === "1" || value === "true";
      return;
    }
  });
  result.text = nextText;
  result.meta = parsed;
  return result;
}

function injectLabsMetaIntoText(rawText, meta = {}) {
  const base = String(rawText || "").trim();
  const parts = [];
  const branch = normalizeLabsBranch(meta.branch);
  const intent = normalizeLabsIntent(meta.intent);
  if (branch) parts.push(`branch=${branch}`);
  if (intent) parts.push(`intent=${intent}`);
  if (meta.sensitive) parts.push("sensitive=1");
  if (!parts.length) return base;
  return `${NOVYN_META_PREFIX}${parts.join(";")}${NOVYN_META_SUFFIX} ${base}`.trim();
}

function getMessageLabsMeta(message) {
  if (!message || typeof message !== "object") return {};
  if (message.novynMeta && typeof message.novynMeta === "object") {
    return message.novynMeta;
  }
  const parsed = extractLabsMetaFromText(message.text);
  return parsed.meta || {};
}

function applyLabsMoodForActiveChat() {
  if (!document.body) return;
  if (!activeFriend) {
    delete document.body.dataset.chatMood;
    return;
  }
  const chatKey = getLabsChatKey(activeFriend, activeChatKind);
  const mood = getLabsMoodForChat(chatKey);
  if (!mood || mood === "auto" || mood === "off") {
    delete document.body.dataset.chatMood;
    return;
  }
  document.body.dataset.chatMood = mood;
}

function appendLabsInsightMessage(text) {
  const content = String(text || "").trim();
  if (!content || !activeFriend) return;
  const chatType = normalizeChatKind(activeChatKind);
  const item = {
    id: `labs-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
    from: "Novyn Labs",
    to: activeFriend,
    toType: chatType,
    kind: chatType,
    groupId: chatType === "group" ? activeFriend : "",
    text: content,
    timestamp: new Date().toISOString(),
    deliveredAt: null,
    seenAt: null,
    pending: false,
    failed: false,
    novynMeta: { intent: "fyi" },
    reactions: {},
  };
  conversationMessages.push(item);
  const currentWindowSize = getCurrentMessageWindowSize();
  messageWindowEnd = conversationMessages.length;
  messageWindowStart = Math.max(0, messageWindowEnd - currentWindowSize);
  renderMessageWindow({ skipSearch: true, maxVisible: currentWindowSize });
  applyMessageSearch();
  pinConversationToBottom();
}

function getLabsCatchupSummary() {
  const incoming = conversationMessages.filter((entry) => (
    entry
    && typeof entry === "object"
    && !entry.deletedAt
    && normalizeName(entry.from) !== normalizeName(me)
  ));
  const recent = incoming.slice(-20);
  if (!recent.length) {
    return "No incoming messages yet in this chat.";
  }
  const questions = recent.filter((entry) => /\?/.test(String(entry.text || ""))).length;
  const actionItems = recent.filter((entry) =>
    /\b(?:please|can you|todo|to-do|need to|asap|urgent)\b/i.test(String(entry.text || ""))
  ).length;
  return `Catch-up: ${recent.length} recent incoming messages, ${questions} questions, ${actionItems} likely action items.`;
}

function handleNovynLabsCommand(rawInput, chatKey = getLabsChatKey()) {
  const value = String(rawInput || "").trim();
  if (!value.startsWith("/")) return false;
  const parts = value.split(/\s+/).filter(Boolean);
  if (!parts.length) return false;
  const cmd = String(parts[0] || "").toLowerCase();
  const arg = String(parts[1] || "").trim().toLowerCase();

  if (cmd === "/labs" || cmd === "/help") {
    if (!arg || arg === "help") {
      appendLabsInsightMessage(
        "Labs commands: /branch, /branchfilter, /intent, /intentfilter, /smart on|off, /trust on|off, /mood, /catchup, /memory."
      );
      return true;
    }
    return false;
  }

  if (cmd === "/branch") {
    if (!chatKey) return true;
    if (!arg || arg === "off" || arg === "none" || arg === "clear") {
      setLabsBranchForChat("", chatKey);
      showToast("Labs branch cleared for this chat.", "success");
      return true;
    }
    const normalized = normalizeLabsBranch(arg);
    if (!normalized) {
      showToast("Invalid branch. Use letters/numbers, up to 32 chars.", "error");
      return true;
    }
    setLabsBranchForChat(normalized, chatKey);
    showToast(`Labs branch set to "${normalized}".`, "success");
    return true;
  }

  if (cmd === "/branchfilter") {
    if (!chatKey) return true;
    setLabsBranchFilterForChat(arg || "all", chatKey);
    const applied = getLabsBranchFilterForChat(chatKey);
    showToast(
      applied === "all"
        ? "Branch filter: all messages."
        : `Branch filter: ${applied}.`,
      "success"
    );
    renderMessages(conversationMessages);
    return true;
  }

  if (cmd === "/intent") {
    if (!chatKey) return true;
    if (!arg || arg === "off" || arg === "none" || arg === "clear") {
      setLabsDefaultIntentForChat("", chatKey);
      showToast("Default intent cleared.", "success");
      return true;
    }
    const normalized = normalizeLabsIntent(arg);
    if (!normalized) {
      showToast("Invalid intent. Use question/decision/action/fyi/urgent.", "error");
      return true;
    }
    setLabsDefaultIntentForChat(normalized, chatKey);
    showToast(`Default intent set to "${normalized}".`, "success");
    return true;
  }

  if (cmd === "/intentfilter") {
    if (!chatKey) return true;
    setLabsIntentFilterForChat(arg || "all", chatKey);
    const applied = getLabsIntentFilterForChat(chatKey);
    showToast(
      applied === "all"
        ? "Intent filter: all messages."
        : `Intent filter: ${applied}.`,
      "success"
    );
    renderMessages(conversationMessages);
    return true;
  }

  if (cmd === "/smart") {
    if (!arg || (arg !== "on" && arg !== "off")) {
      showToast("Use /smart on or /smart off.", "error");
      return true;
    }
    novynLabsState.contextAwareDelivery = arg === "on";
    persistNovynLabsState();
    showToast(
      novynLabsState.contextAwareDelivery
        ? "Context-aware delivery enabled."
        : "Context-aware delivery disabled.",
      "success"
    );
    return true;
  }

  if (cmd === "/trust") {
    if (!chatKey) return true;
    if (!arg || (arg !== "on" && arg !== "off")) {
      showToast("Use /trust on or /trust off.", "error");
      return true;
    }
    setLabsTrustModeForChat(arg === "on", chatKey);
    showToast(arg === "on" ? "Trust mode enabled." : "Trust mode disabled.", "success");
    return true;
  }

  if (cmd === "/mood") {
    if (!chatKey) return true;
    const mood = normalizeLabsMood(arg || "auto");
    setLabsMoodForChat(mood, chatKey);
    applyLabsMoodForActiveChat();
    showToast(`Chat mood set to "${mood}".`, "success");
    return true;
  }

  if (cmd === "/catchup") {
    appendLabsInsightMessage(getLabsCatchupSummary());
    updateLabsLastViewedForChat(chatKey);
    return true;
  }

  if (cmd === "/memory") {
    const branch = getLabsBranchForChat(chatKey) || "none";
    const intent = getLabsDefaultIntentForChat(chatKey) || "none";
    const mood = getLabsMoodForChat(chatKey) || "auto";
    const trust = getLabsTrustModeForChat(chatKey) ? "on" : "off";
    const smart = novynLabsState.contextAwareDelivery ? "on" : "off";
    appendLabsInsightMessage(
      `Labs memory: branch=${branch}, intent=${intent}, mood=${mood}, trust=${trust}, smart=${smart}.`
    );
    return true;
  }

  return false;
}

function getPresenceLabel(mode, options = {}) {
  const normalized = normalizePresenceMode(mode, "online");
  if (options.self && normalized === "offline") return "Invisible";
  if (normalized === "away") return "Away";
  if (normalized === "busy") return "Busy";
  if (normalized === "offline") return "Offline";
  return "Online";
}

function resolveFriendPresenceMode(friend) {
  if (normalizeChatKind(friend?.kind || "friend") === "group") return "offline";
  const online = Boolean(friend?.online);
  const fallback = online ? "online" : "offline";
  const mode = normalizePresenceMode(friend?.presence, fallback);
  if (!online) return "offline";
  return mode === "offline" ? "offline" : mode;
}

function resolveOutgoingTarget(target, kind = "friend") {
  const chatKind = normalizeChatKind(kind);
  const rawTarget = normalizeMojibakeText(target || "").trim();
  if (!rawTarget) return "";
  if (chatKind === "group") {
    return resolveGroupChatId(rawTarget, "group");
  }
  return rawTarget;
}

function getScheduledChatKey(target, kind = "friend") {
  const key = normalizeName(resolveOutgoingTarget(target, kind));
  if (!key) return "";
  return `${normalizeChatKind(kind)}:${key}`;
}

function getChatEntry(target, kind = "friend") {
  const key = normalizeName(target);
  const chatKind = normalizeChatKind(kind);
  if (!key) return null;
  return friends.find((entry) => {
    if (normalizeName(entry?.username) !== key) return false;
    const entryKind = normalizeChatKind(entry?.kind || "friend");
    return entryKind === chatKind;
  }) || null;
}

function getActiveChatEntry() {
  if (!activeFriend) return null;
  return getChatEntry(activeFriend, activeChatKind);
}

function isSameChatTarget(targetA, kindA, targetB, kindB) {
  const chatKindA = normalizeChatKind(kindA);
  const chatKindB = normalizeChatKind(kindB);
  if (chatKindA !== chatKindB) return false;
  if (chatKindA === "group") {
    const resolvedA = normalizeName(resolveGroupChatId(targetA, "group"));
    const resolvedB = normalizeName(resolveGroupChatId(targetB, "group"));
    if (resolvedA && resolvedB) return resolvedA === resolvedB;
  }
  return normalizeName(targetA) === normalizeName(targetB);
}

function getGroupRole(member = {}) {
  if (member?.isOwner) return "owner";
  if (member?.isAdmin) return "admin";
  return "member";
}

function getGroupRolePriority(role) {
  if (role === "owner") return 3;
  if (role === "admin") return 2;
  return 1;
}

function normalizeGroupInfoPayload(raw = {}) {
  if (!raw || typeof raw !== "object") return null;
  const id = normalizeMojibakeText(raw.id || "").trim();
  if (!id) return null;
  const members = Array.isArray(raw.members) ? raw.members : [];
  const normalizedMembers = members.map((memberRaw) => {
    const username = normalizeMojibakeText(memberRaw?.username || "").trim();
    const roleRaw = normalizeName(memberRaw?.role || "");
    const isOwner = Boolean(memberRaw?.isOwner) || roleRaw === "owner";
    const isAdmin = isOwner || Boolean(memberRaw?.isAdmin) || roleRaw === "admin";
    const rawOnline = Boolean(memberRaw?.online);
    const presence = normalizePresenceMode(memberRaw?.presence, rawOnline ? "online" : "offline");
    return {
      username,
      displayName: normalizeMojibakeText(memberRaw?.displayName || "").trim(),
      avatarId: normalizeMojibakeText(memberRaw?.avatarId || "").trim(),
      online: rawOnline && presence !== "offline",
      presence,
      lastSeenAt: normalizeMojibakeText(memberRaw?.lastSeenAt || "").trim(),
      isOwner,
      isAdmin,
      role: isOwner ? "owner" : (isAdmin ? "admin" : "member"),
    };
  }).filter((member) => member.username);

  normalizedMembers.sort((a, b) => {
    const roleDelta = getGroupRolePriority(b.role) - getGroupRolePriority(a.role);
    if (roleDelta !== 0) return roleDelta;
    return a.username.localeCompare(b.username);
  });

  const meKey = normalizeName(raw?.me?.username || me || "");
  const meMember = normalizedMembers.find((member) => normalizeName(member.username) === meKey) || null;
  const meRole = meMember ? getGroupRole(meMember) : "member";

  return {
    id,
    name: normalizeMojibakeText(raw.name || "").trim() || id,
    owner: normalizeMojibakeText(raw.owner || "").trim(),
    createdAt: normalizeMojibakeText(raw.createdAt || "").trim(),
    updatedAt: normalizeMojibakeText(raw.updatedAt || "").trim(),
    members: normalizedMembers,
    me: {
      username: normalizeMojibakeText(raw?.me?.username || me || "").trim(),
      role: meRole,
      isOwner: meRole === "owner",
      isAdmin: meRole === "owner" || meRole === "admin",
    },
  };
}

function resolveGroupChatId(groupId = activeFriend, kind = activeChatKind) {
  const raw = normalizeMojibakeText(groupId || "").trim();
  if (!raw) return "";
  const rawKey = normalizeName(raw);
  const rawLoose = rawKey.replace(/[^a-z0-9]/g, "");
  const groupByDisplay = friends.find((entry) => {
    if (normalizeChatKind(entry?.kind || "friend") !== "group") return false;
    const entryDisplay = normalizeName(entry?.displayName || "");
    if (!entryDisplay) return false;
    const entryLoose = entryDisplay.replace(/[^a-z0-9]/g, "");
    return entryDisplay === rawKey || (rawLoose && entryLoose === rawLoose);
  }) || null;
  const normalizedKind = normalizeChatKind(kind);
  if (normalizedKind === "group") {
    const activeEntry = activeFriend
      && normalizeChatKind(activeChatKind) === "group"
      && normalizeName(activeFriend) === rawKey
      ? getActiveChatEntry()
      : null;
    const entry = activeEntry || getChatEntry(raw, "group") || groupByDisplay;
    return normalizeMojibakeText(entry?.groupId || entry?.username || raw).trim();
  }
  const groupEntry = getChatEntry(raw, "group") || groupByDisplay;
  if (groupEntry) {
    return normalizeMojibakeText(groupEntry.groupId || groupEntry.username || "").trim();
  }
  return raw;
}

function getGroupInfo(groupId = activeFriend, kind = activeChatKind) {
  const resolvedGroupId = resolveGroupChatId(groupId, kind);
  const key = normalizeName(resolvedGroupId);
  if (!key) return null;
  return groupInfoState.byId.get(key) || null;
}

function requestGroupInfo(groupId = activeFriend, options = {}) {
  const requestedKind = normalizeChatKind(options.kind || activeChatKind);
  const resolvedGroupId = resolveGroupChatId(groupId, requestedKind);
  const key = normalizeName(resolvedGroupId);
  if (!key) return;
  if (requestedKind !== "group" && !getChatEntry(resolvedGroupId, "group")) return;
  const now = Date.now();
  const previous = Number(groupInfoState.requestedAt.get(key) || 0);
  const minGap = options.force ? 0 : 650;
  if (now - previous < minGap) return;
  groupInfoState.requestedAt.set(key, now);
  socket.emit("get_group_info", { groupId: resolvedGroupId });
}

function refreshActiveGroupInfo(forceGroupId = "") {
  if (forceGroupId) {
    const activeGroupKey = normalizeName(resolveGroupChatId(activeFriend, activeChatKind));
    const forcedGroupKey = normalizeName(resolveGroupChatId(forceGroupId, "group"));
    if (!activeGroupKey || forcedGroupKey !== activeGroupKey || normalizeChatKind(activeChatKind) !== "group") return;
  }
  const targetGroupId = resolveGroupChatId(forceGroupId || activeFriend, "group");
  if (!targetGroupId || normalizeChatKind(activeChatKind) !== "group") return;
  requestGroupInfo(targetGroupId, { kind: "group", force: true });
}

function setScheduledMessagesForChat(target, kind, messages) {
  const chatKey = getScheduledChatKey(target, kind);
  if (!chatKey) return;
  scheduledState.byChat.set(chatKey, Array.isArray(messages) ? messages.slice() : []);
}

function getScheduledMessagesForChat(target = activeFriend, kind = activeChatKind) {
  const chatKey = getScheduledChatKey(target, kind);
  if (!chatKey) return [];
  const list = scheduledState.byChat.get(chatKey);
  return Array.isArray(list) ? list : [];
}

function readCookie(name) {
  const needle = `${String(name || "").trim()}=`;
  if (!needle) return "";
  const parts = String(document.cookie || "").split(";");
  for (const part of parts) {
    const item = part.trim();
    if (!item.startsWith(needle)) continue;
    try {
      return decodeURIComponent(item.slice(needle.length));
    } catch (_) {
      return item.slice(needle.length);
    }
  }
  return "";
}

function buildCsrfHeaders(base = {}) {
  const headers = { ...(base || {}) };
  const token = readCookie(CSRF_COOKIE_NAME);
  if (token) headers[CSRF_HEADER_NAME] = token;
  return headers;
}

function normalizeHistoryPayload(rawPayload) {
  if (Array.isArray(rawPayload)) {
    return {
      kind: normalizeChatKind(activeChatKind || "friend"),
      toType: normalizeChatKind(activeChatKind || "friend"),
      to: activeFriend || "",
      with: activeFriend || "",
      messages: rawPayload,
    };
  }
  if (!rawPayload || typeof rawPayload !== "object") {
    return {
      kind: normalizeChatKind(activeChatKind || "friend"),
      toType: normalizeChatKind(activeChatKind || "friend"),
      to: activeFriend || "",
      with: activeFriend || "",
      messages: [],
    };
  }
  return rawPayload;
}

function validateOutgoingMessageText(value, options = {}) {
  const text = String(value || "");
  if (!text.trim()) return "";
  if (text.length <= COMPOSER_MAX_MESSAGE_LENGTH) return text;
  if (options.toast !== false) {
    showToast(`Message too long. Limit is ${COMPOSER_MAX_MESSAGE_LENGTH} characters.`, "error");
  }
  return null;
}

function formatFileSize(bytes) {
  const size = Number(bytes);
  if (!Number.isFinite(size) || size <= 0) return "";
  if (size < 1024) return `${Math.round(size)} B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
  return `${(size / (1024 * 1024)).toFixed(1)} MB`;
}

const MOJIBAKE_DETECT_RE = /Ã.|Â.|â€|â€™|â€œ|â€¢|â€“|â€”|â„¢|â€¦|â—|âœ|ðŸ|ï¿½|�/;
const MOJIBAKE_SCORE_RE = /Ã.|Â.|â€|â€™|â€œ|â€¢|â€“|â€”|â„¢|â€¦|â—|âœ|ðŸ|ï¿½|�/g;

function getMojibakeScore(value) {
  const text = String(value || "");
  const matches = text.match(MOJIBAKE_SCORE_RE);
  return matches ? matches.length : 0;
}

function decodeLatin1AsUtf8(value) {
  const text = String(value || "");
  if (!text || typeof TextDecoder !== "function") return text;
  const bytes = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i += 1) {
    bytes[i] = text.charCodeAt(i) & 0xff;
  }
  try {
    return new TextDecoder("utf-8").decode(bytes);
  } catch (_) {
    return text;
  }
}

function normalizeMojibakeText(value) {
  const original = String(value ?? "");
  if (!original) return "";
  let output = original;
  for (let pass = 0; pass < 2; pass += 1) {
    if (!MOJIBAKE_DETECT_RE.test(output)) break;
    const before = getMojibakeScore(output);
    const decoded = decodeLatin1AsUtf8(output);
    if (!decoded || decoded === output) break;
    const after = getMojibakeScore(decoded);
    if (after > before) break;
    output = decoded;
    if (after === 0) break;
  }
  return output.replace(/\uFFFD+/g, "");
}

function sanitizeMessagePayload(rawMessage) {
  if (!rawMessage || typeof rawMessage !== "object") return null;
  const message = { ...rawMessage };
  message.text = normalizeMojibakeText(message.text);
  const labsParsed = extractLabsMetaFromText(message.text);
  message.text = labsParsed.text;
  message.novynMeta = {
    ...(message.novynMeta && typeof message.novynMeta === "object" ? message.novynMeta : {}),
    ...(labsParsed.meta || {}),
  };
  message.from = normalizeMojibakeText(message.from);
  message.to = normalizeMojibakeText(message.to);
  message.groupId = normalizeMojibakeText(message.groupId);
  if (message.replyTo && typeof message.replyTo === "object") {
    message.replyTo = {
      ...message.replyTo,
      text: normalizeMojibakeText(message.replyTo.text),
      from: normalizeMojibakeText(message.replyTo.from),
    };
  }
  if (message.attachment && typeof message.attachment === "object") {
    message.attachment = {
      ...message.attachment,
      name: normalizeMojibakeText(message.attachment.name),
      mime: normalizeMojibakeText(message.attachment.mime),
    };
  }
  return message;
}

function sanitizeFriendRecord(rawFriend) {
  if (!rawFriend || typeof rawFriend !== "object") return rawFriend;
  const kind = normalizeChatKind(rawFriend.kind || "friend");
  const online = Boolean(rawFriend.online);
  const presenceFallback = kind === "group" ? "offline" : (online ? "online" : "offline");
  return {
    ...rawFriend,
    username: normalizeMojibakeText(rawFriend.username),
    displayName: normalizeMojibakeText(rawFriend.displayName),
    bio: normalizeMojibakeText(rawFriend.bio),
    lastMessage: normalizeMojibakeText(rawFriend.lastMessage),
    lastFrom: normalizeMojibakeText(rawFriend.lastFrom),
    online,
    presence: normalizePresenceMode(rawFriend.presence, presenceFallback),
  };
}

function normalizeAttachmentUrl(rawUrl) {
  const value = String(rawUrl || "").trim();
  if (!value) return "";
  if (/^(?:https?:)?\/\//i.test(value) || /^data:/i.test(value) || /^blob:/i.test(value)) {
    return value;
  }
  if (value.startsWith("/uploads/")) return value;
  if (value.startsWith("uploads/")) return `/${value}`;
  if (value.startsWith("./uploads/")) return `/${value.slice(2)}`;

  const bareUploadFilePattern =
    /^[a-z0-9][a-z0-9._-]*\.(?:png|jpe?g|gif|webp|bmp|svg|mp4|mov|webm|mp3|wav|ogg|m4a|aac|pdf|txt|csv|zip|rar|7z|docx?|pptx?|xlsx?)(?:[?#].*)?$/i;
  if (bareUploadFilePattern.test(value) && !value.includes("/")) {
    return `/uploads/${value}`;
  }
  return value;
}

function isLikelyAttachmentUrl(url) {
  const value = String(url || "").trim();
  if (!value) return false;
  if (/^(?:\.?\/)?uploads\//i.test(value)) return true;
  return ATTACHMENT_EXT_PATTERN.test(value);
}

function inferAttachmentKind(url, mime = "", explicitKind = "") {
  if (String(explicitKind || "").trim().toLowerCase() === "image") return "image";
  if (String(mime || "").trim().toLowerCase().startsWith("image/")) return "image";
  return IMAGE_ATTACHMENT_EXT_PATTERN.test(String(url || "").trim()) ? "image" : "file";
}

function attachmentNameFromUrl(url, fallback = "Attachment") {
  const value = String(url || "").trim();
  if (!value) return fallback;
  const clean = value.split("#")[0].split("?")[0];
  const parts = clean.split("/");
  const last = normalizeMojibakeText(parts[parts.length - 1] || "").trim();
  return (last || fallback).slice(0, 120);
}

function normalizeAttachmentPayload(rawAttachment, fallbackUrl = "") {
  const fallbackNormalized = normalizeAttachmentUrl(fallbackUrl || "");
  if (!rawAttachment) {
    if (!fallbackNormalized || !isLikelyAttachmentUrl(fallbackNormalized)) return null;
    const fallbackKind = inferAttachmentKind(fallbackNormalized);
    const fallbackName = fallbackKind === "image" ? "Image attachment" : "Attachment";
    return {
      url: fallbackNormalized,
      name: attachmentNameFromUrl(fallbackNormalized, fallbackName),
      mime: "",
      size: 0,
      kind: fallbackKind,
    };
  }
  const payload = typeof rawAttachment === "string" ? { url: rawAttachment } : rawAttachment;
  if (!payload || typeof payload !== "object") return null;
  const url = normalizeAttachmentUrl(payload.url || fallbackNormalized || "");
  if (!url) return null;
  const mime = normalizeMojibakeText(payload.mime || "").trim().toLowerCase();
  const explicitName = normalizeMojibakeText(payload.name || "").trim().slice(0, 120);
  const kind = inferAttachmentKind(url, mime, payload.kind);
  const fallbackName = kind === "image" ? "Image attachment" : "Attachment";
  const name = explicitName || attachmentNameFromUrl(url, fallbackName);
  const size = Number.isFinite(Number(payload.size))
    ? Math.max(0, Math.floor(Number(payload.size)))
    : 0;
  return {
    url,
    name,
    mime,
    size,
    kind,
  };
}

function getMessageDraftOwnerKey() {
  return normalizeName(me || "");
}

function getMessageDraftStorageKey(ownerKey = getMessageDraftOwnerKey()) {
  const safeOwner = normalizeName(ownerKey || "");
  if (!safeOwner) return "";
  return `${MESSAGE_DRAFTS_KEY}:${safeOwner}`;
}

function ensureMessageDraftsLoaded(force = false) {
  const ownerKey = getMessageDraftOwnerKey();
  if (!ownerKey) {
    loadedDraftOwnerKey = "";
    messageDrafts = new Map();
    return;
  }
  if (!force && loadedDraftOwnerKey === ownerKey) return;

  loadedDraftOwnerKey = ownerKey;
  messageDrafts = new Map();

  const storageKey = getMessageDraftStorageKey(ownerKey);
  if (!storageKey) return;

  try {
    const raw = localStorage.getItem(storageKey);
    if (!raw) return;
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return;
    Object.entries(parsed).forEach(([friendKey, draft]) => {
      const key = normalizeName(friendKey);
      if (!key) return;
      const value = String(draft || "").slice(0, MESSAGE_DRAFT_MAX_LENGTH);
      if (!value.trim()) return;
      messageDrafts.set(key, value);
    });
  } catch (_) {
    // Ignore local storage parse errors for drafts.
  }
}

function persistMessageDrafts() {
  if (!loadedDraftOwnerKey) return;
  const storageKey = getMessageDraftStorageKey(loadedDraftOwnerKey);
  if (!storageKey) return;

  try {
    if (!messageDrafts.size) {
      localStorage.removeItem(storageKey);
      return;
    }
    const payload = {};
    messageDrafts.forEach((draft, friendKey) => {
      payload[friendKey] = draft;
    });
    localStorage.setItem(storageKey, JSON.stringify(payload));
  } catch (_) {
    // Ignore local storage write errors for drafts.
  }
}

function getMessageDraft(friendUsername) {
  const friendKey = normalizeName(friendUsername);
  if (!friendKey) return "";
  ensureMessageDraftsLoaded();
  return messageDrafts.get(friendKey) || "";
}

function setMessageDraft(friendUsername, value) {
  const friendKey = normalizeName(friendUsername);
  if (!friendKey) return;
  ensureMessageDraftsLoaded();

  const nextValue = String(value || "").slice(0, MESSAGE_DRAFT_MAX_LENGTH);
  const nextTrimmed = nextValue.trim();
  const prev = messageDrafts.get(friendKey) || "";

  if (!nextTrimmed) {
    if (messageDrafts.delete(friendKey)) {
      persistMessageDrafts();
    }
    return;
  }

  if (prev === nextValue) return;
  messageDrafts.set(friendKey, nextValue);
  persistMessageDrafts();
}

function removeMessageDraft(friendUsername) {
  const friendKey = normalizeName(friendUsername);
  if (!friendKey) return;
  ensureMessageDraftsLoaded();
  if (!messageDrafts.delete(friendKey)) return;
  persistMessageDrafts();
}

function renameMessageDraft(oldUsername, newUsername) {
  const oldKey = normalizeName(oldUsername);
  const newKey = normalizeName(newUsername);
  if (!oldKey || !newKey || oldKey === newKey) return;
  ensureMessageDraftsLoaded();
  const oldDraft = messageDrafts.get(oldKey);
  if (!oldDraft) return;
  if (!messageDrafts.get(newKey)) {
    messageDrafts.set(newKey, oldDraft);
  }
  messageDrafts.delete(oldKey);
  persistMessageDrafts();
}

function migrateMessageDraftStoreOwner(oldOwnerKey, newOwnerKey) {
  const prevOwner = normalizeName(oldOwnerKey);
  const nextOwner = normalizeName(newOwnerKey);
  if (!prevOwner || !nextOwner || prevOwner === nextOwner) return;

  const prevStorageKey = getMessageDraftStorageKey(prevOwner);
  const nextStorageKey = getMessageDraftStorageKey(nextOwner);
  if (!prevStorageKey || !nextStorageKey) return;

  try {
    const previousRaw = localStorage.getItem(prevStorageKey);
    if (!previousRaw) return;
    const nextRaw = localStorage.getItem(nextStorageKey);
    if (!nextRaw) {
      localStorage.setItem(nextStorageKey, previousRaw);
    }
    localStorage.removeItem(prevStorageKey);
  } catch (_) {
    // Ignore local storage migration errors for drafts.
  }
}

function migratePendingStateStoreOwner(oldOwnerKey, newOwnerKey) {
  const prevOwner = normalizeName(oldOwnerKey);
  const nextOwner = normalizeName(newOwnerKey);
  if (!prevOwner || !nextOwner || prevOwner === nextOwner) return;

  const prevStorageKey = getPendingStateStorageKey(prevOwner);
  const nextStorageKey = getPendingStateStorageKey(nextOwner);
  if (!prevStorageKey || !nextStorageKey) return;

  try {
    const previousRaw = localStorage.getItem(prevStorageKey);
    if (!previousRaw) return;
    const nextRaw = localStorage.getItem(nextStorageKey);
    if (!nextRaw) {
      localStorage.setItem(nextStorageKey, previousRaw);
    }
    localStorage.removeItem(prevStorageKey);
  } catch (_) {
    // Ignore local storage migration errors for pending state.
  }
}

function persistActiveMessageDraft() {
  if (!activeFriend || !messageInput) return;
  setMessageDraft(activeFriend, messageInput.value);
}

function applyActiveMessageDraft() {
  if (!messageInput) return;
  const draft = activeFriend ? getMessageDraft(activeFriend) : "";
  messageInput.value = draft;
  if (sendButton) {
    sendButton.classList.toggle("ready", draft.trim().length > 0);
  }
}

function getPendingStateOwnerKey() {
  return normalizeName(me || "");
}

function getPendingStateStorageKey(ownerKey = getPendingStateOwnerKey()) {
  const safeOwner = normalizeName(ownerKey || "");
  if (!safeOwner) return "";
  return `${PENDING_STATE_KEY}:${safeOwner}`;
}

function withPendingStatePersistenceSuppressed(task) {
  suppressPendingStatePersist += 1;
  try {
    return task();
  } finally {
    suppressPendingStatePersist = Math.max(0, suppressPendingStatePersist - 1);
  }
}

function clearPendingRuntimeState() {
  pendingQueue.length = 0;
  pendingQueueByTempId.clear();
  pendingByTempId.clear();
}

function buildPendingStorageMessage(rawMessage, tempId) {
  if (!rawMessage || !tempId) return null;
  const to = normalizeMojibakeText(rawMessage.to || "").trim();
  if (!to) return null;
  const toType = normalizeChatKind(rawMessage.toType || rawMessage.kind || "friend");
  const text = validateOutgoingMessageText(rawMessage.text, { toast: false });
  if (!text) return null;
  const timestamp = String(rawMessage.timestamp || new Date().toISOString());
  return {
    id: tempId,
    clientTempId: tempId,
    from: me || "You",
    to,
    toType,
    kind: toType,
    groupId: toType === "group" ? to : "",
    text,
    timestamp,
    deliveredAt: null,
    seenAt: null,
    pending: Boolean(rawMessage.pending) && !Boolean(rawMessage.failed),
    failed: Boolean(rawMessage.failed),
    failedAt: rawMessage.failedAt ? String(rawMessage.failedAt) : "",
    replyTo: rawMessage.replyTo && typeof rawMessage.replyTo === "object"
      ? {
          id: String(rawMessage.replyTo.id || "").trim(),
          from: normalizeMojibakeText(rawMessage.replyTo.from || "").trim(),
          text: normalizeMojibakeText(rawMessage.replyTo.text || "").trim(),
        }
      : null,
    attachment: normalizeAttachmentPayload(rawMessage.attachment, text),
    reactions: {},
  };
}

function persistPendingStateNow() {
  if (!loadedPendingOwnerKey) return;
  const storageKey = getPendingStateStorageKey(loadedPendingOwnerKey);
  if (!storageKey) return;
  try {
    if (!pendingByTempId.size && !pendingQueue.length) {
      localStorage.removeItem(storageKey);
      return;
    }

    const messages = [];
    pendingByTempId.forEach((rawMessage, tempId) => {
      const id = String(tempId || "").trim();
      if (!id) return;
      const message = buildPendingStorageMessage(rawMessage, id);
      if (!message) return;
      messages.push(message);
    });

    const queue = [];
    pendingQueue.forEach((entry) => {
      const tempId = String(entry?.tempId || "").trim();
      const payload = entry?.payload || {};
      const text = validateOutgoingMessageText(payload.text, { toast: false });
      if (!tempId || !text) return;
      queue.push({
        tempId,
        attempts: Math.max(0, Math.floor(Number(entry.attempts) || 0)),
        lastAttemptAt: Math.max(0, Math.floor(Number(entry.lastAttemptAt) || 0)),
        nextAttemptAt: Math.max(0, Math.floor(Number(entry.nextAttemptAt) || 0)),
        payload: {
          to: normalizeMojibakeText(payload.to || "").trim(),
          toType: normalizeChatKind(payload.toType || "friend"),
          text,
          clientTempId: tempId,
          replyTo: payload.replyTo && typeof payload.replyTo === "object" ? payload.replyTo : null,
          attachment: normalizeAttachmentPayload(payload.attachment, text),
        },
      });
    });

    const serialized = {
      version: 1,
      owner: loadedPendingOwnerKey,
      savedAt: new Date().toISOString(),
      messages,
      queue,
    };
    localStorage.setItem(storageKey, JSON.stringify(serialized));
  } catch (_) {
    // Ignore storage write failures for pending state.
  }
}

function schedulePersistPendingState() {
  if (!loadedPendingOwnerKey || suppressPendingStatePersist > 0) return;
  if (pendingStatePersistTimer) {
    clearTimeout(pendingStatePersistTimer);
  }
  pendingStatePersistTimer = setTimeout(() => {
    pendingStatePersistTimer = null;
    persistPendingStateNow();
  }, 120);
}

function restorePendingState(force = false) {
  const ownerKey = getPendingStateOwnerKey();
  if (!ownerKey) {
    loadedPendingOwnerKey = "";
    clearPendingRuntimeState();
    return 0;
  }
  if (!force && loadedPendingOwnerKey === ownerKey) {
    return pendingByTempId.size;
  }

  loadedPendingOwnerKey = ownerKey;
  const storageKey = getPendingStateStorageKey(ownerKey);
  let restoredCount = 0;

  withPendingStatePersistenceSuppressed(() => {
    clearPendingRuntimeState();
    if (!storageKey) return;

    try {
      const raw = localStorage.getItem(storageKey);
      if (!raw) return;
      const parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== "object") return;
      const rawMessages = Array.isArray(parsed.messages) ? parsed.messages : [];
      const rawQueue = Array.isArray(parsed.queue) ? parsed.queue : [];

      rawMessages.forEach((entry) => {
        const tempId = String(entry?.clientTempId || entry?.id || "").trim();
        if (!tempId) return;
        const message = buildPendingStorageMessage(entry, tempId);
        if (!message) return;
        const sanitized = sanitizeMessagePayload(message) || message;
        pendingByTempId.set(tempId, sanitized);
      });

      const now = Date.now();
      rawQueue.forEach((entry) => {
        const tempId = String(entry?.tempId || entry?.payload?.clientTempId || "").trim();
        if (!tempId) return;
        const pendingMessage = pendingByTempId.get(tempId);
        if (!pendingMessage || pendingMessage.failed) return;

        const payload = {
          to: pendingMessage.to,
          toType: normalizeChatKind(pendingMessage.toType || pendingMessage.kind || "friend"),
          text: validateOutgoingMessageText(entry?.payload?.text || pendingMessage.text, { toast: false }),
          clientTempId: tempId,
        };
        if (!payload.text) return;
        if (pendingMessage.replyTo) payload.replyTo = pendingMessage.replyTo;
        if (pendingMessage.attachment) payload.attachment = pendingMessage.attachment;

        const restoredEntry = ensurePendingQueueEntry(payload, tempId);
        if (!restoredEntry) return;
        restoredEntry.attempts = Math.max(0, Math.floor(Number(entry?.attempts) || 0));
        restoredEntry.lastAttemptAt = Math.max(0, Math.floor(Number(entry?.lastAttemptAt) || 0));
        const nextAttemptAt = Math.max(0, Math.floor(Number(entry?.nextAttemptAt) || 0));
        restoredEntry.nextAttemptAt = nextAttemptAt > now + PENDING_RETRY_MAX_MS
          ? now
          : nextAttemptAt;
      });

      restoredCount = pendingByTempId.size;
    } catch (_) {
      // Ignore storage parse failures for pending state.
    }
  });

  renderNetworkState();
  return restoredCount;
}

function syncPendingPreviewIntoFriendList() {
  if (!pendingByTempId.size || !Array.isArray(friends) || !friends.length) return;
  let touched = false;
  const nextFriends = friends.map((entry) => ({ ...entry }));

  pendingByTempId.forEach((message) => {
    if (!message || !message.to) return;
    const target = String(message.to || "").trim();
    const kind = normalizeChatKind(message.toType || message.kind || "friend");
    const index = nextFriends.findIndex((friend) =>
      isSameChatTarget(friend?.username, friend?.kind || "friend", target, kind)
    );
    if (index < 0) return;

    const current = nextFriends[index];
    const pendingTs = getTimestampSortValue(message.timestamp || "");
    const currentTs = getTimestampSortValue(current?.lastTimestamp || "");
    if (pendingTs < currentTs) return;

    const attachment = normalizeAttachmentPayload(message.attachment, message.text);
    const pendingPreview = attachment
      ? (attachment.kind === "image" ? "Image attachment" : (attachment.name || "Attachment"))
      : String(message.text || "");

    nextFriends[index] = {
      ...current,
      lastMessage: pendingPreview,
      lastFrom: me || current?.lastFrom || "You",
      lastTimestamp: message.timestamp || current?.lastTimestamp || "",
    };
    touched = true;
  });

  if (touched) {
    friends = nextFriends;
  }
}

function appendRestoredPendingMessages(messages, target, kind = "friend") {
  if (!Array.isArray(messages) || !pendingByTempId.size || !target) return messages;

  const staleTempIds = [];
  const existingTempIds = new Set();
  messages.forEach((message) => {
    if (!message) return;
    const tempId = String(message.clientTempId || "").trim();
    const messageId = String(message.id || "").trim();
    if (tempId) existingTempIds.add(tempId);
    if (messageId.startsWith("tmp-")) existingTempIds.add(messageId);
  });

  const pendingMatches = [];
  pendingByTempId.forEach((message, tempId) => {
    if (!message || !tempId) return;
    if (!isSameChatTarget(message.to, message.toType || message.kind || "friend", target, kind)) return;
    if (existingTempIds.has(tempId)) {
      staleTempIds.push(tempId);
      return;
    }
    pendingMatches.push(message);
  });

  if (!pendingMatches.length && !staleTempIds.length) return messages;

  staleTempIds.forEach((tempId) => {
    pendingByTempId.delete(tempId);
    removePendingFromQueue(tempId);
  });

  const merged = messages.concat(pendingMatches);
  merged.sort((a, b) => {
    const tsDiff = getTimestampSortValue(a?.timestamp || "") - getTimestampSortValue(b?.timestamp || "");
    if (tsDiff !== 0) return tsDiff;
    const aKey = String(a?.id || a?.clientTempId || "");
    const bKey = String(b?.id || b?.clientTempId || "");
    return aKey.localeCompare(bKey);
  });

  if (staleTempIds.length) {
    schedulePersistPendingState();
  }
  return merged;
}

function isNativePlatform() {
  try {
    return Boolean(
      window.Capacitor &&
      typeof window.Capacitor.isNativePlatform === "function" &&
      window.Capacitor.isNativePlatform()
    );
  } catch (_) {
    return false;
  }
}

function openExternalLink(href) {
  const url = String(href || "").trim();
  if (!url) return;
  const cap = window.Capacitor;
  const browser = cap && cap.Plugins && cap.Plugins.Browser;
  if (browser && typeof browser.open === "function") {
    browser.open({ url });
    return;
  }
  const popup = window.open(url, "_blank", "noopener,noreferrer");
  if (!popup) {
    if (!isNativePlatform()) {
      window.location.href = url;
      return;
    }
    try {
      const base = window.location.origin;
      const resolved = new URL(url, base);
      if (resolved.origin !== base) {
        window.location.href = resolved.href;
      }
    } catch (_) {
      // Ignore URL parsing errors.
    }
  }
}

function buildAttachmentDownloadUrl(fileUrl, fileName = "file") {
  const baseUrl = String(fileUrl || "").trim();
  if (!baseUrl) return "";
  const joiner = baseUrl.includes("?") ? "&" : "?";
  return `${baseUrl}${joiner}download=1&name=${encodeURIComponent(fileName || "file")}`;
}

function triggerAttachmentDownload(downloadUrl, fileName = "file") {
  const href = String(downloadUrl || "").trim();
  if (!href || href === "#") return;
  const name = String(fileName || "file").trim() || "file";
  const link = document.createElement("a");
  link.href = href;
  link.setAttribute("download", name);
  link.style.display = "none";
  document.body.appendChild(link);
  link.click();
  link.remove();
}

function buildCapturedPhotoFilename() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  const hours = String(now.getHours()).padStart(2, "0");
  const minutes = String(now.getMinutes()).padStart(2, "0");
  const seconds = String(now.getSeconds()).padStart(2, "0");
  return `photo-${year}${month}${day}-${hours}${minutes}${seconds}.jpg`;
}

function createCapturedPhotoFile(blob) {
  const name = buildCapturedPhotoFilename();
  try {
    return new File([blob], name, {
      type: "image/jpeg",
      lastModified: Date.now(),
    });
  } catch (_) {
    blob.name = name;
    return blob;
  }
}

function stopCameraCaptureStream() {
  const stream = cameraCaptureState.stream;
  cameraCaptureState.stream = null;
  if (!stream || typeof stream.getTracks !== "function") return;
  stream.getTracks().forEach((track) => {
    try {
      track.stop();
    } catch (_) {
      // Ignore camera track stop errors.
    }
  });
}

const cameraCaptureModal = (() => {
  const modal = document.createElement("div");
  modal.id = "cameraCaptureModal";
  modal.className = "camera-capture-modal hidden";
  modal.setAttribute("role", "dialog");
  modal.setAttribute("aria-modal", "true");
  modal.setAttribute("aria-label", "Capture photo");
  modal.innerHTML = `
    <div class="camera-capture-backdrop" data-camera-capture-close="1"></div>
    <div class="camera-capture-card">
      <div class="camera-capture-toolbar">
        <span class="camera-capture-title">Capture photo</span>
        <button id="cameraCaptureClose" type="button" class="camera-capture-btn camera-capture-close" aria-label="Close camera">Close</button>
      </div>
      <div class="camera-capture-stage">
        <video id="cameraCaptureVideo" class="camera-capture-video" autoplay playsinline muted></video>
      </div>
      <div class="camera-capture-actions">
        <button id="cameraCaptureSwitch" type="button" class="camera-capture-btn">Switch</button>
        <button id="cameraCaptureTake" type="button" class="camera-capture-btn camera-capture-take">Take photo</button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);

  const videoEl = modal.querySelector("#cameraCaptureVideo");
  const closeBtn = modal.querySelector("#cameraCaptureClose");
  const switchBtn = modal.querySelector("#cameraCaptureSwitch");
  const takeBtn = modal.querySelector("#cameraCaptureTake");
  const backdrop = modal.querySelector(".camera-capture-backdrop");
  let lastFocused = null;

  function setButtonsDisabled(isDisabled) {
    const disabled = Boolean(isDisabled);
    if (takeBtn) takeBtn.disabled = disabled;
    if (switchBtn) switchBtn.disabled = disabled;
  }

  async function requestCameraStream(preferredFacing = "environment") {
    if (!navigator.mediaDevices?.getUserMedia) {
      throw new Error("Camera is not supported in this browser.");
    }
    const attempts = [];
    if (preferredFacing) {
      attempts.push({
        audio: false,
        video: {
          facingMode: { ideal: preferredFacing },
          width: { ideal: 1920 },
          height: { ideal: 1080 },
        },
      });
      attempts.push({
        audio: false,
        video: {
          facingMode: preferredFacing,
        },
      });
    }
    attempts.push({ audio: false, video: true });

    let lastError = null;
    for (const constraints of attempts) {
      try {
        return await navigator.mediaDevices.getUserMedia(constraints);
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError || new Error("Unable to access camera.");
  }

  async function bindStream(preferredFacing = cameraCaptureState.facingMode) {
    stopCameraCaptureStream();
    const stream = await requestCameraStream(preferredFacing || "environment");
    cameraCaptureState.stream = stream;
    cameraCaptureState.facingMode = preferredFacing || cameraCaptureState.facingMode || "environment";
    if (videoEl) {
      videoEl.srcObject = stream;
      try {
        await videoEl.play();
      } catch (_) {
        // Some browsers may block autoplay until video is visible.
      }
    }
  }

  function close() {
    modal.classList.add("hidden");
    document.body.classList.remove("camera-capture-open");
    stopCameraCaptureStream();
    if (videoEl) {
      try {
        videoEl.pause();
      } catch (_) {}
      videoEl.srcObject = null;
    }
    if (lastFocused && typeof lastFocused.focus === "function") {
      lastFocused.focus();
    }
    lastFocused = null;
    setButtonsDisabled(false);
    cameraCaptureState.opening = false;
  }

  async function open() {
    if (cameraCaptureState.opening) return;
    if (!navigator.mediaDevices?.getUserMedia) {
      throw new Error("Camera is not supported in this browser.");
    }
    lastFocused = document.activeElement;
    modal.classList.remove("hidden");
    document.body.classList.add("camera-capture-open");
    setButtonsDisabled(true);
    cameraCaptureState.opening = true;
    try {
      await bindStream(cameraCaptureState.facingMode || "environment");
      setButtonsDisabled(false);
      if (takeBtn) takeBtn.focus();
    } catch (error) {
      close();
      throw error;
    } finally {
      cameraCaptureState.opening = false;
    }
  }

  async function switchFacingMode() {
    if (cameraCaptureState.opening) return;
    const nextFacing = cameraCaptureState.facingMode === "environment" ? "user" : "environment";
    setButtonsDisabled(true);
    cameraCaptureState.opening = true;
    try {
      await bindStream(nextFacing);
      cameraCaptureState.facingMode = nextFacing;
    } finally {
      cameraCaptureState.opening = false;
      if (!modal.classList.contains("hidden")) {
        setButtonsDisabled(false);
      }
    }
  }

  async function capturePhotoAsFile() {
    if (!videoEl || !(videoEl.srcObject instanceof MediaStream)) {
      throw new Error("Camera stream is not ready.");
    }
    const width = Number(videoEl.videoWidth || 0);
    const height = Number(videoEl.videoHeight || 0);
    if (!width || !height) {
      throw new Error("Camera is still loading. Try again.");
    }
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext("2d");
    if (!context) {
      throw new Error("Unable to capture photo.");
    }
    context.drawImage(videoEl, 0, 0, width, height);
    const blob = await new Promise((resolve) => {
      canvas.toBlob(resolve, "image/jpeg", 0.92);
    });
    if (!blob) {
      throw new Error("Unable to capture photo.");
    }
    return createCapturedPhotoFile(blob);
  }

  if (closeBtn) {
    closeBtn.addEventListener("click", close);
  }
  if (switchBtn) {
    switchBtn.addEventListener("click", async () => {
      try {
        await switchFacingMode();
      } catch (error) {
        console.error(error);
        showToast("Could not switch camera.", "error");
        if (!modal.classList.contains("hidden")) {
          setButtonsDisabled(false);
        }
      }
    });
  }
  if (takeBtn) {
    takeBtn.addEventListener("click", async () => {
      if (!activeFriend) {
        showToast("Choose a friend before sending a photo.", "error");
        return;
      }
      if (attachmentUploadState.active) {
        showToast("Please wait for the current upload to finish.", "info");
        return;
      }
      setButtonsDisabled(true);
      try {
        const capturedPhoto = await capturePhotoAsFile();
        close();
        await uploadAttachmentFromPicker(capturedPhoto);
      } catch (error) {
        console.error(error);
        showToast(String(error?.message || "Unable to capture photo."), "error");
        if (!modal.classList.contains("hidden")) {
          setButtonsDisabled(false);
        }
      }
    });
  }
  if (backdrop) {
    backdrop.addEventListener("click", close);
  }
  modal.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof Element)) return;
    if (target.closest("[data-camera-capture-close='1']")) {
      close();
    }
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !modal.classList.contains("hidden")) {
      close();
    }
  });

  return {
    open,
    close,
    isOpen() {
      return !modal.classList.contains("hidden");
    },
  };
})();

const imageViewer = (() => {
  const modal = document.createElement("div");
  modal.id = "imageViewerModal";
  modal.className = "image-viewer-modal hidden";
  modal.setAttribute("role", "dialog");
  modal.setAttribute("aria-modal", "true");
  modal.setAttribute("aria-label", "Image preview");
  modal.innerHTML = `
    <div class="image-viewer-backdrop" data-image-viewer-close="1"></div>
    <div class="image-viewer-card">
      <div class="image-viewer-toolbar">
        <span class="image-viewer-name" id="imageViewerName">Image</span>
        <div class="image-viewer-actions">
          <a id="imageViewerDownload" class="image-viewer-btn" href="#">Download</a>
          <button id="imageViewerClose" type="button" class="image-viewer-btn image-viewer-close" aria-label="Close image preview">Close</button>
        </div>
      </div>
      <div class="image-viewer-stage">
        <img id="imageViewerImg" class="image-viewer-img" alt="Image preview" />
      </div>
    </div>
  `;
  document.body.appendChild(modal);

  const imgEl = modal.querySelector("#imageViewerImg");
  const nameEl = modal.querySelector("#imageViewerName");
  const closeBtn = modal.querySelector("#imageViewerClose");
  const downloadEl = modal.querySelector("#imageViewerDownload");
  const backdrop = modal.querySelector(".image-viewer-backdrop");
  let lastFocused = null;

  function close() {
    modal.classList.add("hidden");
    document.body.classList.remove("image-viewer-open");
    if (imgEl) {
      imgEl.removeAttribute("src");
    }
    if (nameEl) {
      nameEl.textContent = "Image";
    }
    if (downloadEl) {
      downloadEl.setAttribute("href", "#");
      downloadEl.removeAttribute("download");
    }
    if (lastFocused && typeof lastFocused.focus === "function") {
      lastFocused.focus();
    }
    lastFocused = null;
  }

  function open(payload = {}) {
    const src = String(payload.src || "").trim();
    if (!src || !imgEl) return;
    const fileName = String(payload.fileName || "").trim() || "image";
    lastFocused = document.activeElement;
    imgEl.src = src;
    imgEl.alt = fileName;
    if (nameEl) {
      nameEl.textContent = fileName;
    }
    if (downloadEl) {
      downloadEl.setAttribute("href", buildAttachmentDownloadUrl(src, fileName));
      downloadEl.setAttribute("download", fileName);
    }
    modal.classList.remove("hidden");
    document.body.classList.add("image-viewer-open");
    if (closeBtn) {
      closeBtn.focus();
    }
  }

  if (closeBtn) {
    closeBtn.addEventListener("click", close);
  }
  if (downloadEl) {
    downloadEl.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      triggerAttachmentDownload(
        downloadEl.getAttribute("href") || "",
        downloadEl.getAttribute("download") || "image"
      );
    });
  }
  if (backdrop) {
    backdrop.addEventListener("click", close);
  }
  modal.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof Element)) return;
    if (target.closest("[data-image-viewer-close='1']")) {
      close();
    }
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !modal.classList.contains("hidden")) {
      close();
    }
  });

  return { open, close };
})();

function canPreviewFileInViewer(fileUrl, mimeType, fileName) {
  const url = String(fileUrl || "").toLowerCase();
  const mime = String(mimeType || "").toLowerCase();
  const name = String(fileName || "").toLowerCase();
  if (mime === "application/pdf") return true;
  if (/\.pdf($|[?#])/.test(url) || /\.pdf$/.test(name)) return true;
  return false;
}

const fileViewer = (() => {
  const modal = document.createElement("div");
  modal.id = "fileViewerModal";
  modal.className = "image-viewer-modal hidden";
  modal.setAttribute("role", "dialog");
  modal.setAttribute("aria-modal", "true");
  modal.setAttribute("aria-label", "File preview");
  modal.innerHTML = `
    <div class="image-viewer-backdrop" data-file-viewer-close="1"></div>
    <div class="image-viewer-card">
      <div class="image-viewer-toolbar">
        <span class="image-viewer-name" id="fileViewerName">Attachment</span>
        <div class="image-viewer-actions">
          <a id="fileViewerDownload" class="image-viewer-btn" href="#">Download</a>
          <button id="fileViewerClose" type="button" class="image-viewer-btn image-viewer-close" aria-label="Close file preview">Close</button>
        </div>
      </div>
      <div class="image-viewer-stage">
        <iframe id="fileViewerFrame" class="file-viewer-frame hidden" title="File preview"></iframe>
        <div id="fileViewerFallback" class="file-viewer-fallback hidden">
          <div class="file-viewer-fallback-title">Preview unavailable</div>
          <div class="file-viewer-fallback-sub">Use the download button to open this file.</div>
          <div id="fileViewerMeta" class="file-viewer-meta"></div>
        </div>
      </div>
    </div>
  `;
  document.body.appendChild(modal);

  const nameEl = modal.querySelector("#fileViewerName");
  const frameEl = modal.querySelector("#fileViewerFrame");
  const fallbackEl = modal.querySelector("#fileViewerFallback");
  const metaEl = modal.querySelector("#fileViewerMeta");
  const closeBtn = modal.querySelector("#fileViewerClose");
  const downloadEl = modal.querySelector("#fileViewerDownload");
  const backdrop = modal.querySelector(".image-viewer-backdrop");
  let lastFocused = null;

  function close() {
    modal.classList.add("hidden");
    document.body.classList.remove("image-viewer-open");
    if (nameEl) {
      nameEl.textContent = "Attachment";
    }
    if (frameEl) {
      frameEl.classList.add("hidden");
      frameEl.removeAttribute("src");
    }
    if (fallbackEl) {
      fallbackEl.classList.add("hidden");
    }
    if (metaEl) {
      metaEl.textContent = "";
    }
    if (downloadEl) {
      downloadEl.setAttribute("href", "#");
      downloadEl.removeAttribute("download");
    }
    if (lastFocused && typeof lastFocused.focus === "function") {
      lastFocused.focus();
    }
    lastFocused = null;
  }

  function open(payload = {}) {
    const src = String(payload.src || "").trim();
    if (!src) return;
    const fileName = String(payload.fileName || "").trim() || "Attachment";
    const mime = String(payload.mime || "").trim();
    const size = Number(payload.size);
    const canPreview = canPreviewFileInViewer(src, mime, fileName);

    lastFocused = document.activeElement;
    if (nameEl) {
      nameEl.textContent = fileName;
    }
    if (downloadEl) {
      downloadEl.setAttribute("href", buildAttachmentDownloadUrl(src, fileName));
      downloadEl.setAttribute("download", fileName);
    }

    if (canPreview && frameEl) {
      frameEl.setAttribute("src", src);
      frameEl.classList.remove("hidden");
      if (fallbackEl) fallbackEl.classList.add("hidden");
      if (metaEl) metaEl.textContent = "";
    } else {
      if (frameEl) {
        frameEl.classList.add("hidden");
        frameEl.removeAttribute("src");
      }
      if (fallbackEl) fallbackEl.classList.remove("hidden");
      if (metaEl) {
        const sizeText = formatFileSize(size);
        const typeText = mime || "Unknown file type";
        metaEl.textContent = sizeText ? `${typeText} - ${sizeText}` : typeText;
      }
    }

    modal.classList.remove("hidden");
    document.body.classList.add("image-viewer-open");
    if (closeBtn) closeBtn.focus();
  }

  if (closeBtn) {
    closeBtn.addEventListener("click", close);
  }
  if (downloadEl) {
    downloadEl.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      triggerAttachmentDownload(
        downloadEl.getAttribute("href") || "",
        downloadEl.getAttribute("download") || "file"
      );
    });
  }
  if (backdrop) {
    backdrop.addEventListener("click", close);
  }
  modal.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof Element)) return;
    if (target.closest("[data-file-viewer-close='1']")) {
      close();
    }
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !modal.classList.contains("hidden")) {
      close();
    }
  });

  return { open, close };
})();

async function openComposerCameraCapture() {
  if (!activeFriend) {
    showToast("Choose a friend before sending a photo.", "error");
    return;
  }
  const safety = getFriendSafety(activeFriend, activeChatKind);
  if (safety.blocked) {
    showToast(safety.blockedByMe ? "Unblock this contact to send photos." : "This user has blocked you.", "error");
    return;
  }
  if (attachmentUploadState.active) {
    showToast("Please wait for the current upload to finish.", "info");
    return;
  }
  if (messageInput?.disabled) return;

  if (!navigator.mediaDevices?.getUserMedia) {
    if (cameraCaptureInput) {
      cameraCaptureInput.value = "";
      cameraCaptureInput.click();
      return;
    }
    showToast("Camera is not supported in this browser.", "error");
    return;
  }

  try {
    await cameraCaptureModal.open();
  } catch (error) {
    console.error(error);
    if (cameraCaptureInput) {
      cameraCaptureInput.value = "";
      cameraCaptureInput.click();
      showToast("Live camera unavailable. Opened image picker instead.", "info");
      return;
    }
    showToast("Unable to open camera.", "error");
  }
}

function setSidebarView(nextView, options = {}) {
  const allowed = ["messages", "calls", "contacts", "discover"];
  const view = allowed.includes(nextView) ? nextView : "messages";
  const prevView = sidebarView;
  closeStatusViewer();
  sidebarView = view;
  document.body.dataset.rail = view;
  navRailButtons.forEach((btn) => {
    const btnView = btn.dataset.rail || "";
    if (btnView === "settings") return;
    btn.classList.toggle("active", btnView === view);
  });
  if (sidebarBrand) {
    if (view === "messages") {
      sidebarBrand.innerHTML = sidebarBrandHTML || "Novyn";
    } else if (view === "calls") {
      sidebarBrand.textContent = "Calls";
    } else if (view === "contacts") {
      sidebarBrand.textContent = "Contacts";
    } else if (view === "discover") {
      sidebarBrand.textContent = "Discover";
    }
  }
  if (sidebarTopActions) {
    sidebarTopActions.style.display = view === "messages" ? "" : "none";
  }
  if (view !== "messages") {
    closeChatQuickMenu();
  }
  if (networkPill) {
    networkPill.style.display = view === "messages" ? "" : "none";
  }
  if (sidebarSearch) {
    if (view === "calls") {
      sidebarSearch.placeholder = "Search calls...";
    } else if (view === "contacts") {
      sidebarSearch.placeholder = "Search contacts...";
    } else if (view === "discover") {
      sidebarSearch.placeholder = "Find people or groups...";
    } else {
      sidebarSearch.placeholder = "Search chats...";
    }
  }
  if (view === "discover") {
    requestDiscoverOnline();
  }
  if (view === "contacts" && prevView !== "contacts") {
    if (sidebarSearch && sidebarSearch.value) sidebarSearch.value = "";
    if (friendSearchQuery) friendSearchQuery = "";
  }
  if (view !== "calls" && callFilter !== "all") {
    setCallFilter("all");
  }
  if (view !== "contacts") {
    setRequestsPanelOpen(false);
  }
  if (!options.silent) {
    renderRequests();
    renderFriends();
    renderCallHistory();
    renderDiscover();
  }
  syncMessageFilterUi();
}

function setRequestsPanelOpen(nextState) {
  if (!contactsRequestsPanel || !contactsRequestsBtn) return;
  const isOpen = Boolean(nextState);
  contactsRequestsPanel.classList.toggle("is-open", isOpen);
  contactsRequestsPanel.setAttribute("aria-hidden", isOpen ? "false" : "true");
  contactsRequestsBtn.setAttribute("aria-expanded", isOpen ? "true" : "false");
}

function updateRequestsBadge() {
  if (!contactsRequestsBadge) return;
  const count = requests.length || 0;
  if (count > 0) {
    contactsRequestsBadge.textContent = count > 99 ? "99+" : String(count);
    contactsRequestsBadge.style.display = "";
  } else {
    contactsRequestsBadge.style.display = "none";
  }
}

function setSettingsOpen(nextState) {
  if (!settingsPanel) return;
  settingsOpen = Boolean(nextState);
  if (settingsOpen) closeChatQuickMenu();
  document.body.classList.toggle("settings-open", settingsOpen);
  settingsPanel.setAttribute("aria-hidden", settingsOpen ? "false" : "true");
  if (navSettingsBtn) navSettingsBtn.classList.toggle("active", settingsOpen);
  if (settingsOpen) {
    navRailButtons.forEach((btn) => {
      const btnView = btn.dataset.rail || "";
      if (btnView && btnView !== "settings") btn.classList.remove("active");
    });
    document.body.dataset.rail = "settings";
    syncSettingsPanel();
  } else {
    setSidebarView(sidebarView, { silent: true });
  }
}

function clearSidebarSearch() {
  if (!sidebarSearch) return;
  sidebarSearch.value = "";
  friendSearchQuery = "";
}

function isMobileViewportLayout() {
  const hasPanelsApi = window._novynPanels && typeof window._novynPanels.isMobile === "function";
  if (hasPanelsApi) return window._novynPanels.isMobile();
  return window.innerWidth <= MOBILE_BP;
}

function syncViewportLayoutMetrics() {
  const root = document.documentElement;
  if (!root) return;

  const vv = window.visualViewport;
  const viewportHeight = vv && Number.isFinite(vv.height)
    ? vv.height
    : window.innerHeight;
  if (Number.isFinite(viewportHeight) && viewportHeight > 0) {
    root.style.setProperty("--app-vh", `${Math.round(viewportHeight)}px`);
  }

  let keyboardInset = 0;
  if (vv && Number.isFinite(vv.height)) {
    const layoutHeight = Number.isFinite(window.innerHeight) ? window.innerHeight : viewportHeight;
    const offsetTop = Number.isFinite(vv.offsetTop) ? vv.offsetTop : 0;
    keyboardInset = Math.max(0, Math.round(layoutHeight - vv.height - offsetTop));
  }
  root.style.setProperty("--keyboard-inset", `${keyboardInset}px`);

  const composerFocused = Boolean(
    isMobileViewportLayout()
    && messageInput
    && !messageInput.disabled
    && document.activeElement === messageInput
  );
  if (document.body) {
    document.body.classList.toggle("composer-focused", composerFocused);
    document.body.classList.toggle("keyboard-open", composerFocused && keyboardInset > 0);
  }

  if (!bottomTabBar) return;

  const tabPosition = window.getComputedStyle(bottomTabBar).position;
  const usingBottomTabs = tabPosition === "fixed";
  if (!usingBottomTabs) {
    root.style.setProperty("--tab-safe-h", "60px");
    return;
  }

  const tabHeight = bottomTabBar.getBoundingClientRect().height;
  if (Number.isFinite(tabHeight) && tabHeight > 0) {
    const clampedHeight = Math.round(Math.min(110, Math.max(52, tabHeight)));
    root.style.setProperty("--tab-safe-h", `${clampedHeight}px`);
  }
}

function showSidebarListOnMobile(options = {}) {
  const usePanels = window._novynPanels && typeof window._novynPanels.show === "function";
  const isMobile = usePanels && typeof window._novynPanels.isMobile === "function"
    ? window._novynPanels.isMobile()
    : window.innerWidth <= MOBILE_BP;
  if (!isMobile) return;
  if (usePanels) {
    window._novynPanels.show("friends", { silent: options.silent !== false });
    return;
  }
  showSidebarOnMobile();
}

function switchRail(nextView, options = {}) {
  const view = String(nextView || "").trim();
  if (!view) return;
  if (view === "settings") {
    setSettingsOpen(true);
    return;
  }
  if (settingsOpen) setSettingsOpen(false);
  setSidebarView(view, options);
  showSidebarListOnMobile({ silent: true });
}

window.switchRail = switchRail;
window._novynOpenSettingsPanel = () => setSettingsOpen(true);
window._novynCloseSettingsPanel = () => setSettingsOpen(false);
window._novynToggleSettingsPanel = () => setSettingsOpen(!settingsOpen);

function syncSettingsPresenceUi() {
  const mode = normalizePresenceMode(myPresenceMode, "online");
  if (settingsPresenceLine) {
    settingsPresenceLine.dataset.presence = mode;
  }
  if (settingsPresenceText) {
    settingsPresenceText.textContent = mode === "online" ? "Active now" : getPresenceLabel(mode, { self: true });
  }
  if (statusPillButtons.length) {
    statusPillButtons.forEach((btn) => {
      const buttonMode = normalizePresenceMode(btn.dataset.status, "online");
      btn.classList.toggle("active", buttonMode === mode);
      btn.setAttribute("aria-pressed", buttonMode === mode ? "true" : "false");
    });
  }
}

function clearPresenceSyncTimer() {
  if (!presenceSyncTimer) return;
  clearTimeout(presenceSyncTimer);
  presenceSyncTimer = null;
}

function emitPresenceModeToServer(mode) {
  const normalizedMode = normalizePresenceMode(mode, myPresenceMode);
  pendingPresenceSyncMode = normalizedMode;
  if (!socketAvailable || !socket || !socket.connected) return;

  clearPresenceSyncTimer();
  let acked = false;
  socket.emit("set_presence_mode", { status: normalizedMode }, (ack) => {
    acked = true;
    clearPresenceSyncTimer();
    if (!ack || ack.ok !== true) {
      pendingPresenceSyncMode = normalizedMode;
      return;
    }
    pendingPresenceSyncMode = "";
    const acknowledgedMode = normalizePresenceMode(ack?.status, normalizedMode);
    if (acknowledgedMode !== myPresenceMode) {
      setMyPresenceMode(acknowledgedMode, { emit: false, toast: false, manual: false });
    }
  });

  presenceSyncTimer = setTimeout(() => {
    presenceSyncTimer = null;
    if (!acked) {
      pendingPresenceSyncMode = normalizedMode;
    }
  }, 2500);
}

function flushPendingPresenceSync() {
  if (!pendingPresenceSyncMode) return;
  const now = Date.now();
  if (now < nextPresenceSyncRetryAt) return;
  nextPresenceSyncRetryAt = now + 3000;
  emitPresenceModeToServer(pendingPresenceSyncMode);
}

function clearPresenceActivityTimers() {
  if (presenceIdleTimer) {
    clearTimeout(presenceIdleTimer);
    presenceIdleTimer = null;
  }
  if (presenceHiddenTimer) {
    clearTimeout(presenceHiddenTimer);
    presenceHiddenTimer = null;
  }
}

function schedulePresenceActivityTimers() {
  clearPresenceActivityTimers();
  if (!isDashboardPage || !me) return;
  if (manualPresenceMode !== "online") return;

  if (document.hidden) {
    presenceHiddenTimer = setTimeout(() => {
      if (!isDashboardPage || !me) return;
      if (manualPresenceMode !== "online") return;
      if (normalizePresenceMode(myPresenceMode, "online") !== "online") return;
      presenceAutoAwayActive = true;
      setMyPresenceMode("away", { emit: true, toast: false, manual: false });
    }, PRESENCE_HIDDEN_AWAY_MS);
    return;
  }

  presenceIdleTimer = setTimeout(() => {
    if (!isDashboardPage || !me) return;
    if (manualPresenceMode !== "online") return;
    if (normalizePresenceMode(myPresenceMode, "online") !== "online") return;
    presenceAutoAwayActive = true;
    setMyPresenceMode("away", { emit: true, toast: false, manual: false });
  }, PRESENCE_IDLE_AWAY_MS);
}

function markPresenceActivity(options = {}) {
  if (!isDashboardPage || !me) return;
  const now = Date.now();
  const skipThrottle = Boolean(options.skipThrottle);
  if (!skipThrottle && now - lastPresenceActivityEventAt < PRESENCE_ACTIVITY_THROTTLE_MS) return;
  lastPresenceActivityEventAt = now;

  if (!document.hidden && presenceAutoAwayActive && manualPresenceMode === "online") {
    presenceAutoAwayActive = false;
    setMyPresenceMode("online", { emit: true, toast: false, manual: false });
  }
  schedulePresenceActivityTimers();
}

function setMyPresenceMode(nextMode, options = {}) {
  const previous = normalizePresenceMode(myPresenceMode, "online");
  const mode = normalizePresenceMode(nextMode, previous);
  myPresenceMode = mode;
  if (options.manual !== false) {
    manualPresenceMode = mode;
    presenceAutoAwayActive = false;
  }
  syncSettingsPresenceUi();
  if (options.emit && socketAvailable) {
    emitPresenceModeToServer(mode);
  }
  if (options.toast && mode !== previous) {
    showToast(`Status set to ${getPresenceLabel(mode, { self: true })}.`, "success");
  }
  schedulePresenceActivityTimers();
}

function syncSettingsPanel() {
  if (!settingsPanel) return;
  const handle = me ? `@${me}` : "@you";
  if (settingsProfileName) settingsProfileName.textContent = getMyDisplayName();
  if (settingsProfileHandle) settingsProfileHandle.textContent = handle;
  if (settingsAvatar) {
    const fallback = (me || "?").slice(0, 2).toUpperCase();
    if (myProfile.avatarId && window._novynAvatarUtils) {
      window._novynAvatarUtils.applyAvatarToEl(settingsAvatar, myProfile.avatarId, fallback);
    } else {
      settingsAvatar.textContent = fallback;
      settingsAvatar.style.background = "";
    }
  }
  syncSettingsPresenceUi();
}

function setCallFilter(nextFilter) {
  const allowed = ["all", "missed", "video", "outgoing"];
  callFilter = allowed.includes(nextFilter) ? nextFilter : "all";
  callFilterButtons.forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.callFilter === callFilter);
  });
  renderCallHistory();
}

function collectCallHistoryEntries() {
  const entries = [];
  const seen = new Set();
  const pushEntry = (friend, message, log) => {
    if (!friend || !message) return;
    const messageKind = normalizeChatKind(
      message?.toType || (message?.groupId ? "group" : (friend?.kind || "friend"))
    );
    if (messageKind !== "friend") return;
    if (normalizeChatKind(friend?.kind || "friend") !== "friend") return;
    const friendKey = normalizeName(friend?.username || "");
    if (friendKey.startsWith("grp_")) return;
    const messageId = String(message.id || "").trim();
    const timestampKey = getTimestampSortValue(message.timestamp || friend.lastTimestamp || "");
    const key = messageId
      ? `id:${normalizeName(messageId)}`
      : `${friendKey}|${timestampKey}|${message.text || ""}`;
    if (seen.has(key)) return;
    seen.add(key);
    entries.push({ friend, message, log });
  };

  const cached = readCallHistoryCache();
  cached.forEach((entry) => {
    if (!entry || !entry.text) return;
    const log = parseCallLogPayload(entry.text);
    if (!log) return;
    const friendName = String(entry.friend || "").trim();
    if (!friendName) return;
    const friend = findFriend(friendName)
      || friends.find((item) => (
        normalizeChatKind(item?.kind || "friend") === "group"
        && normalizeName(item?.displayName || "") === normalizeName(friendName)
      ))
      || { username: friendName, displayName: "" };
    pushEntry(friend, {
      text: entry.text,
      timestamp: entry.timestamp || "",
      from: entry.from || friendName,
    }, log);
  });

  friends.forEach((friend) => {
    const rawText = friend?.lastMessage || "";
    if (!rawText) return;
    const log = parseCallLogPayload(rawText);
    if (!log) return;
    pushEntry(friend, {
      text: rawText,
      timestamp: friend.lastTimestamp || "",
      from: friend.lastFrom || friend.username || "",
    }, log);
  });

  if (activeFriend && Array.isArray(conversationMessages)) {
    const friend = findFriend(activeFriend) || { username: activeFriend, displayName: "" };
    conversationMessages.forEach((message) => {
      if (!message) return;
      const log = parseCallLogPayload(message.text);
      if (!log) return;
      pushEntry(friend, message, log);
    });
  }

  return entries;
}

function getTimestampSortValue(iso) {
  const timestamp = Date.parse(iso || "");
  return Number.isNaN(timestamp) ? 0 : timestamp;
}

function formatCallHistoryDateLabel(iso) {
  const date = new Date(iso || "");
  if (Number.isNaN(date.getTime())) return "EARLIER";
  const now = new Date();
  const startOfNow = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const daysDiff = Math.round((startOfNow - startOfDate) / (24 * 60 * 60 * 1000));
  if (daysDiff === 0) return "TODAY";
  if (daysDiff === 1) return "YESTERDAY";
  return date
    .toLocaleDateString([], { weekday: "short", month: "short", day: "numeric" })
    .replace(",", "")
    .toUpperCase();
}

function createCallHistorySeparator(tagName, iso) {
  const separator = document.createElement(tagName);
  separator.className = "call-history-separator";
  separator.textContent = formatCallHistoryDateLabel(iso);
  return separator;
}

function isBadCallStatus(status) {
  return BAD_CALL_STATUSES.has(normalizeName(status));
}

function renderCallHistory() {
  if (!callHistoryList) return;
  callHistoryList.innerHTML = "";

  const query = friendSearchQuery;
  const entries = collectCallHistoryEntries();
  const filtered = entries.filter((entry) => {
    const log = entry.log || parseCallLogPayload(entry.message?.text || "");
    if (!log) return false;
    const message = entry.message || {};
    const fromMe = normalizeName(message.from) === normalizeName(me);
    const display = getCallLogDisplay(log, fromMe);
    if (callFilter === "missed") {
      if (!MISSED_CALL_FILTER_STATUSES.has(normalizeName(log.status))) return false;
    }
    if (callFilter === "video") {
      if (log.mediaType && log.mediaType !== "video") return false;
    }
    if (callFilter === "outgoing" && display.direction !== "outgoing") {
      return false;
    }
    if (!query) return true;
    const name = getFriendDisplayName(entry.friend || {});
    const handle = entry.friend?.username || "";
    return normalizeSearchText(`${name} ${handle}`).includes(query);
  });

  if (!filtered.length) {
    const empty = document.createElement("li");
    empty.className = "item-card list-empty";
    const rawQuery = sidebarSearch ? sidebarSearch.value.trim() : "";
    empty.textContent = query ? `No calls match "${rawQuery || friendSearchQuery}"` : "No calls yet";
    callHistoryList.appendChild(empty);
    return;
  }

  filtered.sort((a, b) => {
    const aTs = a.message?.timestamp || a.friend?.lastTimestamp || "";
    const bTs = b.message?.timestamp || b.friend?.lastTimestamp || "";
    return getTimestampSortValue(bTs) - getTimestampSortValue(aTs);
  });

  let lastDateKey = "";
  filtered.forEach((entry) => {
    const friend = entry.friend || {};
    const message = entry.message || {};
    const timestamp = message.timestamp || friend.lastTimestamp || "";
    const dateKey = getLocalDateKey(timestamp) || "unknown";
    if (dateKey !== lastDateKey) {
      lastDateKey = dateKey;
      callHistoryList.appendChild(createCallHistorySeparator("li", timestamp));
    }
    const log = entry.log || parseCallLogPayload(message.text);
    if (!log) return;
    const fromMe = normalizeName(message.from) === normalizeName(me);
    const display = getCallLogDisplay(log, fromMe);
    const timeText = formatFriendTime(timestamp);
    const isBadStatus = isBadCallStatus(display.status);
    const isNeutralStatus = display.status === "ended";
    const statusClass = isNeutralStatus ? "neutral" : (isBadStatus ? "bad" : "good");
    const targetKind = normalizeChatKind(friend?.kind || "friend");

    const item = document.createElement("li");
    const mediaClass = log.mediaType === "video" ? "video" : "voice";
    item.className = `call-log-item ${display.direction === "incoming" ? "incoming" : "outgoing"} status-${statusClass} ${mediaClass}`;

    const icon = document.createElement("div");
    icon.className = "call-log-item-icon";
    icon.innerHTML = `${getCallMediaIconSvg(log.mediaType)}${getCallDirectionBadgeSvg(display.direction, statusClass)}`;

    const content = document.createElement("div");
    content.className = "call-log-item-content";
    const title = document.createElement("div");
    title.className = "call-log-item-title";
    title.textContent = getFriendDisplayName(friend);
    const subtitle = document.createElement("div");
    subtitle.className = "call-log-item-subtitle";
    subtitle.textContent = display.subtitle;
    if (isBadStatus) subtitle.classList.add("is-alert");
    content.append(title, subtitle);

    const time = document.createElement("div");
    time.className = "call-log-item-time";
    time.textContent = timeText || "";

    const actionBtn = document.createElement("button");
    actionBtn.type = "button";
    actionBtn.className = "call-log-action";
    actionBtn.title = "Call back";
    actionBtn.innerHTML = getCallMediaIconSvg("audio");
    actionBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      if (friend?.username) {
        setActiveFriend(friend.username, targetKind);
        setTimeout(() => startVoiceCall(), 240);
      }
    });

    item.addEventListener("click", () => {
      if (friend?.username) setActiveFriend(friend.username, targetKind);
    });

    item.append(icon, content, time, actionBtn);
    callHistoryList.appendChild(item);
  });
}

function showChatOnMobile() {
  if (!mobileSidebar || !mobileChat) return;
  if (window.innerWidth > MOBILE_BP) return;
  mobileSidebar.setAttribute("data-mob-hidden", "true");
  mobileChat.removeAttribute("data-mob-hidden");
  document.body.classList.add("mob-chat-open");
  document.body.classList.remove("mob-list-open");
}

function showSidebarOnMobile() {
  if (!mobileSidebar || !mobileChat) return;
  if (window.innerWidth > MOBILE_BP) return;
  mobileSidebar.removeAttribute("data-mob-hidden");
  mobileChat.setAttribute("data-mob-hidden", "true");
  document.body.classList.remove("mob-chat-open");
  document.body.classList.add("mob-list-open");
}

function setActiveChatTarget(friendName, chatKind = activeChatKind) {
  if (!socketAvailable || !isDashboardPage) return;
  const kind = normalizeChatKind(chatKind);
  const target = resolveOutgoingTarget(friendName, kind);
  if (!target) {
    socket.emit("set_active_chat", "");
    return;
  }
  socket.emit("set_active_chat", {
    to: target,
    toType: kind,
  });
}

function getFriendSearchBlob(friend) {
  const displayName = getFriendDisplayName(friend);
  const bio = cleanDisplayName(friend?.bio);
  const username = normalizeMojibakeText(friend?.username || "");
  const lastMessage = normalizeMojibakeText(friend?.lastMessage || "");
  const lastFrom = normalizeMojibakeText(friend?.lastFrom || "");
  const preview = friendPreview(friend);
  return normalizeSearchText(
    `${displayName} ${username} ${bio} ${lastMessage} ${lastFrom} ${preview}`
  );
}

function isBlockedFriendEntry(friend) {
  if (!friend) return false;
  if (normalizeChatKind(friend?.kind || "friend") === "group") return false;
  const key = normalizeName(friend?.username || "");
  return Boolean(friend?.blockedByMe || friend?.blockedYou || (key && safetyState.blocked.has(key)));
}

function getBlockedUsersForSettings() {
  const list = Array.isArray(friends) ? friends : [];
  return list
    .filter((friend) => normalizeChatKind(friend?.kind || "friend") === "friend")
    .map((friend) => {
      const username = String(friend?.username || "").trim();
      if (!username) return null;
      const safety = getFriendSafety(username, friend?.kind || "friend");
      if (!safety.blockedByMe) return null;
      return {
        username,
        displayName: getFriendDisplayName(friend),
        avatarId: String(friend?.avatarId || ""),
      };
    })
    .filter(Boolean)
    .sort((a, b) => String(a.displayName || "").localeCompare(String(b.displayName || "")));
}

function getMessageFilterCounts() {
  const list = Array.isArray(friends) ? friends : [];
  let groups = 0;
  let blocked = 0;
  let unread = 0;
  for (const friend of list) {
    const isGroup = normalizeChatKind(friend?.kind || "friend") === "group";
    if (isGroup) groups += 1;
    if (isBlockedFriendEntry(friend)) blocked += 1;
    if ((Number(friend?.unreadCount) || 0) > 0) unread += 1;
  }
  return {
    all: list.length,
    groups,
    blocked,
    unread,
  };
}

function syncMessageFilterUi() {
  const counts = getMessageFilterCounts();
  if (chatFilterCountAll) chatFilterCountAll.textContent = String(counts.all);
  if (chatFilterCountGroups) chatFilterCountGroups.textContent = String(counts.groups);
  if (chatFilterCountBlocked) chatFilterCountBlocked.textContent = String(counts.blocked);
  if (chatFilterCountUnread) chatFilterCountUnread.textContent = String(counts.unread);
  const labelMap = {
    all: "All chats",
    groups: "Group chats",
    blocked: "Blocked chats",
    unread: "Unread chats",
  };
  if (messageViewMeta) {
    messageViewMeta.textContent = labelMap[messageListFilter] || "All chats";
  }
  chatCategoryButtons.forEach((btn) => {
    const value = String(btn.dataset.chatFilter || "all").trim();
    btn.classList.toggle("active", value === messageListFilter);
  });
  if (chatQuickMenu) {
    const quickItems = Array.from(chatQuickMenu.querySelectorAll("[data-quick-action]"));
    quickItems.forEach((item) => {
      const action = String(item.dataset.quickAction || "").trim();
      item.classList.toggle("active", action === messageListFilter);
    });
  }
}

function setMessageListFilter(nextFilter, options = {}) {
  const allowed = ["all", "groups", "blocked", "unread"];
  const normalized = allowed.includes(String(nextFilter || "").trim()) ? String(nextFilter || "").trim() : "all";
  messageListFilter = normalized;
  syncMessageFilterUi();
  if (options.render !== false) {
    renderFriends();
  }
}

function closeChatQuickMenu() {
  if (!chatQuickMenu) return;
  chatQuickMenu.classList.add("hidden");
  if (chatQuickMenuBtn) chatQuickMenuBtn.setAttribute("aria-expanded", "false");
}

function toggleChatQuickMenu() {
  if (!chatQuickMenu || !chatQuickMenuBtn) return;
  const open = chatQuickMenu.classList.toggle("hidden");
  chatQuickMenuBtn.setAttribute("aria-expanded", open ? "false" : "true");
  syncMessageFilterUi();
}

function applySafetyState(payload = {}) {
  const blocked = Array.isArray(payload.blocked) ? payload.blocked : [];
  const muted = Array.isArray(payload.muted) ? payload.muted : [];
  safetyState.blocked = new Set(blocked.map((name) => normalizeName(name)).filter(Boolean));
  safetyState.muted = new Set(muted.map((name) => normalizeName(name)).filter(Boolean));
}

function getFriendSafety(username, kind = "") {
  const friend = findFriend(username, kind || "");
  const chatKind = normalizeChatKind(friend?.kind || kind || "friend");
  const key = normalizeName(username || friend?.username || "");
  if (chatKind === "group") {
    return {
      key,
      friend,
      muted: false,
      blockedByMe: false,
      blockedYou: false,
      blocked: false,
    };
  }
  const blockedByMe = Boolean(friend?.blockedByMe || (key && safetyState.blocked.has(key)));
  const blockedYou = Boolean(friend?.blockedYou);
  const muted = Boolean(friend?.muted || (key && safetyState.muted.has(key)));
  return {
    key,
    friend,
    muted,
    blockedByMe,
    blockedYou,
    blocked: blockedByMe || blockedYou,
  };
}

function syncSafetyActionButtons() {
  const hasActive = Boolean(activeFriend);
  const activeEntry = hasActive ? getActiveChatEntry() : null;
  const isGroup = normalizeChatKind(activeEntry?.kind || activeChatKind) === "group";
  const safety = hasActive ? getFriendSafety(activeFriend, activeEntry?.kind || activeChatKind) : null;

  if (infoCallBtn) {
    infoCallBtn.disabled = !hasActive || isGroup || Boolean(safety?.blocked);
    infoCallBtn.title = !hasActive
      ? "Voice call"
      : isGroup
        ? "Group calls coming soon"
      : safety?.blocked
        ? "Calls unavailable while blocked"
        : "Voice call";
  }

  if (infoMuteBtn) {
    const muted = Boolean(safety?.muted);
    infoMuteBtn.disabled = !hasActive || isGroup;
    infoMuteBtn.classList.toggle("hidden", isGroup);
    infoMuteBtn.dataset.icon = muted ? "off" : "on";
    const muteLabel = infoMuteBtn.querySelector("span");
    if (muteLabel) muteLabel.textContent = muted ? "Unmute" : "Mute";
    else infoMuteBtn.textContent = muted ? "Unmute" : "Mute";
    infoMuteBtn.title = hasActive ? (muted ? "Unmute notifications" : "Mute notifications") : "Mute";
  }

  if (infoBlockBtn) {
    const blockedByMe = Boolean(safety?.blockedByMe);
    infoBlockBtn.disabled = !hasActive || isGroup;
    infoBlockBtn.classList.toggle("hidden", isGroup);
    infoBlockBtn.classList.toggle("is-active", blockedByMe);
    infoBlockBtn.textContent = blockedByMe ? "Unblock" : "Block";
    infoBlockBtn.title = hasActive ? (blockedByMe ? "Unblock this contact" : "Block this contact") : "Block";
  }

  if (infoReportBtn) {
    infoReportBtn.disabled = !hasActive || isGroup;
    infoReportBtn.classList.toggle("hidden", isGroup);
  }
}

function syncActiveConversationAccess() {
  if (!activeFriend) {
    syncSafetyActionButtons();
    return;
  }
  const activeEntry = getActiveChatEntry();
  const isGroup = normalizeChatKind(activeEntry?.kind || activeChatKind) === "group";
  const safety = getFriendSafety(activeFriend, activeEntry?.kind || activeChatKind);
  const blocked = Boolean(safety.blocked);
  setComposerEnabled(isGroup ? true : !blocked);
  if (messageInput) {
    if (isGroup) {
      messageInput.placeholder = "Message this group...";
    } else if (safety.blockedByMe) {
      messageInput.placeholder = "You blocked this user.";
    } else if (safety.blockedYou) {
      messageInput.placeholder = "This user blocked you.";
    } else {
      messageInput.placeholder = "Message";
    }
  }
  syncSafetyActionButtons();
}

function clearStoredSession() {
  try {
    sessionStorage.removeItem(SESSION_KEY);
  } catch (_) {
    // Ignore storage failures.
  }
  try {
    localStorage.removeItem(SESSION_KEY);
    localStorage.removeItem(REMEMBER_KEY);
  } catch (_) {}
}

function redirectToLogin() {
  if (window.location.pathname === LOGIN_PATH) return;
  window.location.replace(LOGIN_PATH);
}

function prepareLogoutTransition() {
  logoutInProgress = true;
  cameraCaptureModal.close();
  clearPresenceActivityTimers();
  clearPresenceSyncTimer();
  pendingPresenceSyncMode = "";
  clearStoredSession();
  ensureDashboardSession._pending = null;
  resumeSocketSession._pending = false;
  if (socketAvailable && socket.connected && typeof socket.disconnect === "function") {
    try {
      socket.disconnect();
    } catch (_) {
      // Ignore disconnect failures while navigating away.
    }
  }
}

window._novynPrepareLogout = prepareLogoutTransition;

function refreshAuthSessionSilently() {
  const request = authApi?.refreshSession
    ? authApi.refreshSession()
    : fetch("/api/auth/refresh", {
        method: "POST",
        headers: buildCsrfHeaders(),
        credentials: "same-origin",
      });
  Promise.resolve(request).catch(() => {});
}

function resumeSocketSession(force = false) {
  if (!socketAvailable || !isDashboardPage) return;
  if (!socket.connected) return;
  if (resumeSocketSession._pending && !force) return;
  resumeSocketSession._pending = true;
  socket.emit("resume_session");
}

resumeSocketSession._pending = false;

async function hasValidHttpSession() {
  if (authApi?.hasValidSession) {
    try {
      const result = await authApi.hasValidSession();
      return Boolean(result?.ok);
    } catch (_) {
      return false;
    }
  }

  try {
    const response = await fetch("/api/auth/session", {
      method: "GET",
      cache: "no-store",
      credentials: "same-origin",
    });
    if (response.ok) return true;
    if (response.status !== 401) return false;
  } catch (_) {
    return false;
  }

  try {
    const refreshResponse = await fetch("/api/auth/refresh", {
      method: "POST",
      headers: buildCsrfHeaders(),
      credentials: "same-origin",
    });
    if (!refreshResponse.ok) return false;
    const retry = await fetch("/api/auth/session", {
      method: "GET",
      cache: "no-store",
      credentials: "same-origin",
    });
    return retry.ok;
  } catch (_) {
    return false;
  }
}

async function ensureDashboardSession(force = false) {
  if (!isDashboardPage) return false;
  if (ensureDashboardSession._pending && !force) {
    return ensureDashboardSession._pending;
  }

  const checkPromise = (async () => {
    const ok = await hasValidHttpSession();
    if (!ok) {
      clearStoredSession();
      redirectToLogin();
      return false;
    }
    if (socket.connected) {
      resumeSocketSession(true);
    }
    return true;
  })();

  ensureDashboardSession._pending = checkPromise;
  try {
    return await checkPromise;
  } finally {
    ensureDashboardSession._pending = null;
  }
}

ensureDashboardSession._pending = null;

if (isDashboardPage) {
  void ensureDashboardSession();
}

function getLocalDateKey(iso) {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function formatDateSeparatorLabel(iso) {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "Unknown date";
  const now = new Date();

  const startOfNow = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const daysDiff = Math.round((startOfNow - startOfDate) / (24 * 60 * 60 * 1000));

  if (daysDiff === 0) return "Today";
  if (daysDiff === 1) return "Yesterday";
  return date.toLocaleDateString([], { weekday: "short", month: "short", day: "numeric" });
}

function formatFullTimestamp(iso) {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleString([], {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

function getMessageStatusKey(message) {
  if (message?.failed) return "failed";
  if (message?.pending) return "pending";
  const messageKind = normalizeChatKind(message?.toType || (message?.groupId ? "group" : "friend"));
  if (messageKind === "group") {
    const seenCount = Number(message?.seenCount);
    if (Number.isFinite(seenCount) && seenCount > 0) return "seen";
    const myKey = normalizeName(me);
    const seenBy = Array.isArray(message?.seenBy)
      ? Array.from(new Set(message.seenBy.map((entry) => normalizeName(entry)).filter(Boolean)))
      : [];
    const hasBeenSeenByOthers = seenBy.some((viewerKey) => viewerKey && viewerKey !== myKey);
    if (hasBeenSeenByOthers) return "seen";
  }
  if (message?.seenAt) return "seen";
  if (message?.deliveredAt) return "delivered";
  return "sent";
}

const notificationAudio = {
  context: null,
  unlocked: false,
};
const notificationState = {
  permissionRequested: false,
};
const pushState = {
  publicKey: "",
  inFlight: false,
  lastEndpoint: "",
  lastUser: "",
};

function unlockNotificationAudio() {
  if (notificationAudio.unlocked) return;
  const AudioCtx = window.AudioContext || window.webkitAudioContext;
  if (!AudioCtx) return;
  try {
    if (!notificationAudio.context) notificationAudio.context = new AudioCtx();
    const ctx = notificationAudio.context;
    if (ctx.state === "suspended") ctx.resume().catch(() => {});
    notificationAudio.unlocked = true;
  } catch (_) {
    // Ignore browsers that block audio context creation.
  }
}

function playIncomingPing() {
  const ctx = notificationAudio.context;
  if (!notificationAudio.unlocked || !ctx) return;
  try {
    const now = ctx.currentTime;
    const oscillator = ctx.createOscillator();
    const gain = ctx.createGain();

    oscillator.type = "sine";
    oscillator.frequency.setValueAtTime(740, now);
    oscillator.frequency.exponentialRampToValueAtTime(560, now + 0.14);

    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.045, now + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.16);

    oscillator.connect(gain);
    gain.connect(ctx.destination);
    oscillator.start(now);
    oscillator.stop(now + 0.17);
  } catch (_) {
    // Ignore transient audio failures.
  }
}

async function requestNotificationPermission() {
  if (!("Notification" in window)) return "denied";
  if (Notification.permission !== "default") return Notification.permission;
  if (notificationState.permissionRequested) return Notification.permission;
  notificationState.permissionRequested = true;
  try {
    return await Notification.requestPermission();
  } catch (_) {
    return Notification.permission;
  }
}

function canSystemNotify() {
  return "Notification" in window && Notification.permission === "granted";
}

function shouldSystemNotify() {
  return document.hidden || !document.hasFocus();
}

function isAppVisible() {
  return !document.hidden && document.hasFocus();
}

function urlBase64ToUint8Array(base64String) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; i += 1) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

async function getPushPublicKey() {
  if (pushState.publicKey) return pushState.publicKey;
  try {
    const res = await fetch("/api/push/public-key", { cache: "no-store" });
    if (!res.ok) return "";
    const data = await res.json();
    pushState.publicKey = String(data?.publicKey || "").trim();
    return pushState.publicKey;
  } catch (_) {
    return "";
  }
}

async function ensurePushSubscription(requestPermission = false) {
  if (!("serviceWorker" in navigator) || !("PushManager" in window)) return;
  if (!socketAvailable || !me) return;
  if (pushState.inFlight) return;

  if (Notification.permission === "default" && requestPermission) {
    await requestNotificationPermission();
  }
  if (Notification.permission !== "granted") return;

  pushState.inFlight = true;
  try {
    const registration = await navigator.serviceWorker.ready;
    if (!registration?.pushManager) return;

    let subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      const publicKey = await getPushPublicKey();
      if (!publicKey) return;
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(publicKey),
      });
    }

    const payload = subscription.toJSON ? subscription.toJSON() : subscription;
    const endpoint = payload?.endpoint || "";
    const userKey = normalizeName(me);
    if (!endpoint) return;
    if (pushState.lastEndpoint === endpoint && pushState.lastUser === userKey) return;
    pushState.lastEndpoint = endpoint;
    pushState.lastUser = userKey;
    socket.emit("push_subscribe", { subscription: payload });
  } catch (err) {
    console.warn("Push subscription failed:", err);
  } finally {
    pushState.inFlight = false;
  }
}

function showSystemNotification(title, options = {}) {
  if (!canSystemNotify()) return false;
  try {
    const notification = new Notification(title, options);
    notification.onclick = () => {
      try {
        window.focus();
      } catch (_) {
        // Ignore focus errors.
      }
    };
    return true;
  } catch (_) {
    return false;
  }
}

function formatNotificationPreview(text, maxLen = 120) {
  const cleaned = normalizeMojibakeText(text).replace(/\s+/g, " ").trim();
  if (!cleaned) return "New message";
  if (cleaned.length <= maxLen) return cleaned;
  return `${cleaned.slice(0, maxLen - 3)}...`;
}

function notifyIncomingMessage(message, options = {}) {
  if (!message) return;
  if (normalizeName(message.from) === normalizeName(me)) return;
  const messageKind = normalizeChatKind(message?.toType || (message?.groupId ? "group" : "friend"));
  const chatTarget = messageKind === "group"
    ? normalizeName(message?.groupId || message?.toKey || message?.to || "")
    : normalizeName(message?.from);
  const safety = messageKind === "friend" ? getFriendSafety(message.from, "friend") : null;
  if (!options.force && safety?.muted) return;
  const isActiveThread = activeFriend && isSameChatTarget(chatTarget, messageKind, activeFriend, activeChatKind);
  if (!options.force && isActiveThread && isAppVisible()) return;
  const senderName = options.senderName || (() => {
    const sender = findFriend(message.from, "friend");
    return sender ? getFriendDisplayName(sender) : message.from;
  })();
  const callPreview = formatCallLogPreview(message.text, false);
  const bodyText = callPreview || formatNotificationPreview(message.text);
  if (messageKind === "group") {
    const groupId = normalizeName(message?.groupId || message?.toKey || message?.to || "");
    const groupEntry = getChatEntry(groupId, "group");
    const groupName = groupEntry ? getFriendDisplayName(groupEntry) : (message?.to || "Group");
    showSystemNotification(`New message in ${groupName}`, {
      body: formatNotificationPreview(`${senderName}: ${bodyText}`),
      tag: `grp-${groupId || "unknown"}`,
    });
  } else {
    showSystemNotification(`New message from ${senderName}`, {
      body: formatNotificationPreview(bodyText),
      tag: `msg-${normalizeName(message.from) || "unknown"}`,
    });
  }
}

function notifyIncomingCall(from, options = {}) {
  if (!from) return;
  const safety = getFriendSafety(from);
  if (!options.force && safety.muted) return;
  if (!options.force && !shouldSystemNotify()) return;
  const displayName = getCallPeerDisplayName(from);
  const body = options.blocked
    ? `${displayName} tried to call you.`
    : `${displayName} is calling.`;
  showSystemNotification("Incoming call", {
    body,
    tag: `call-${normalizeName(from) || "unknown"}`,
  });
}

function handleUserGesture() {
  unlockNotificationAudio();
  requestNotificationPermission();
  ensurePushSubscription(true);
}

document.addEventListener("pointerdown", handleUserGesture, { passive: true });
document.addEventListener("keydown", handleUserGesture, { passive: true });

/**
 * Smooth-scroll the messages container to the bottom.
 * Uses scrollTo with behavior:'smooth' so it animates instead of jumping.
 * Falls back to instant scroll for initial history load (skipAnimation).
 */
function scrollToBottom(skipAnimation = false) {
  if (!messagesEl) return;
  const maxTop = Math.max(0, messagesEl.scrollHeight - messagesEl.clientHeight);
  if (skipAnimation) {
    messagesEl.scrollTop = maxTop;
    const snap = () => {
      const nextTop = Math.max(0, messagesEl.scrollHeight - messagesEl.clientHeight);
      messagesEl.scrollTop = nextTop;
    };
    requestAnimationFrame(snap);
    setTimeout(snap, 80);
    return;
  }
  messagesEl.scrollTo({
    top:      maxTop,
    behavior: "smooth",
  });
}

function pinConversationToBottom(forceLatest = false) {
  if (!messagesEl) return;
  if (!forceLatest && isMessageViewportMutationActive()) return;
  if (forceLatest || hasNewerMessages()) {
    showLatestMessages();
    return;
  }
  scrollState.pinnedToBottom = true;
  scrollToBottom(true);
  requestAnimationFrame(() => scrollToBottom(true));
  setTimeout(() => scrollToBottom(true), 90);
}

/**
 * Returns true when the user is already near the bottom of the message list.
 * We only auto-scroll when they're within 120px of the bottom Ã¢â‚¬â€ if they've
 * scrolled up to read history, we don't yank them back down on new messages.
 */
function isNearBottom() {
  const threshold = 120;
  return (
    messagesEl.scrollHeight - messagesEl.scrollTop - messagesEl.clientHeight <=
    threshold
  );
}

function isNearTop() {
  if (!messagesEl) return false;
  return messagesEl.scrollTop <= LOAD_OLDER_SHOW_TOP_THRESHOLD;
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Network state Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

function beginMessageViewportMutation() {
  suppressMessageViewportHandlers += 1;
}

function endMessageViewportMutation() {
  suppressMessageViewportHandlers = Math.max(0, suppressMessageViewportHandlers - 1);
}

function isMessageViewportMutationActive() {
  return suppressMessageViewportHandlers > 0;
}

function getFailedPendingTempIds() {
  const failedTempIds = [];
  pendingByTempId.forEach((message, tempId) => {
    if (!message || !message.failed || !tempId) return;
    failedTempIds.push(tempId);
  });
  return failedTempIds;
}

function retryAllFailedMessages() {
  const failedTempIds = getFailedPendingTempIds();
  if (!failedTempIds.length) {
    showToast("No failed messages to retry.", "info");
    return;
  }
  failedTempIds.forEach((tempId) => retryFailedMessage(tempId, { toast: false }));
  const label = failedTempIds.length === 1 ? "message" : "messages";
  showToast(`Retrying ${failedTempIds.length} failed ${label}...`, "info");
}

function renderNetworkState() {
  if (!connectionLabel) return;
  const queuedCount = pendingQueue.length;
  const failedCount = getFailedPendingTempIds().length;
  const queuedSuffix = queuedCount ? ` | ${queuedCount} queued` : "";
  const failedSuffix = failedCount ? ` | ${failedCount} failed` : "";
  connectionLabel.textContent = `${networkStateLabel || ""}${queuedSuffix}${failedSuffix}`;
  if (networkPill) {
    networkPill.classList.remove("connected", "offline");
    if (networkStateMode === "connected") networkPill.classList.add("connected");
    if (networkStateMode === "offline")   networkPill.classList.add("offline");
  }
  if (retryFailedBtn) {
    retryFailedBtn.classList.toggle("hidden", failedCount === 0);
    retryFailedBtn.disabled = failedCount === 0;
    retryFailedBtn.textContent = failedCount > 1 ? `Retry failed (${failedCount})` : "Retry failed";
  }
}

function setNetworkState(label, state) {
  networkStateLabel = label;
  networkStateMode = state;
  renderNetworkState();
}

function syncBrowserNetworkState() {
  if (typeof navigator !== "undefined" && navigator && navigator.onLine === false) {
    setNetworkState("Offline (no internet)", "offline");
    return;
  }
  if (socketAvailable && socket && socket.connected) {
    setNetworkState("Connected", "connected");
    return;
  }
  if (socketAvailable) {
    setNetworkState("Reconnecting...", "offline");
    return;
  }
  setNetworkState("Realtime unavailable", "offline");
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Toast Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

function showToast(message, type = "info") {
  if (!toast) return;
  toast.textContent = normalizeMojibakeText(message);
  toast.classList.remove("hidden", "error", "success");
  if (type === "error")   toast.classList.add("error");
  if (type === "success") toast.classList.add("success");

  clearTimeout(showToast._timer);
  showToast._timer = setTimeout(() => {
    toast.classList.add("hidden");
  }, 2800);
}

const appDialog = (() => {
  const modal = document.createElement("div");
  modal.id = "appDialogModal";
  modal.className = "confirm-modal";
  modal.style.display = "none";
  modal.setAttribute("role", "dialog");
  modal.setAttribute("aria-modal", "true");
  modal.setAttribute("aria-label", "Dialog");
  modal.innerHTML = `
    <div class="confirm-modal-backdrop"></div>
    <div class="confirm-modal-card settings-modal-card app-dialog-card">
      <div class="confirm-modal-icon app-dialog-icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round">
          <path d="M12 3v10"/><circle cx="12" cy="17" r="1.1"/><path d="M4.6 19.1 11 4.2a1.1 1.1 0 0 1 2 0l6.4 14.9A1.1 1.1 0 0 1 18.4 21H5.6a1.1 1.1 0 0 1-1-1.9z"/>
        </svg>
      </div>
      <h3 id="appDialogTitle">Confirm action</h3>
      <p class="confirm-modal-desc" id="appDialogDesc"></p>
      <div class="app-dialog-form hidden" id="appDialogForm">
        <label class="app-dialog-label" id="appDialogLabel" for="appDialogInput">Value</label>
        <textarea id="appDialogInput" class="app-dialog-input" rows="4" maxlength="400" spellcheck="false"></textarea>
      </div>
      <div class="confirm-modal-btns">
        <button type="button" class="confirm-modal-cancel" id="appDialogCancel">Cancel</button>
        <button type="button" class="settings-confirm" id="appDialogConfirm">Confirm</button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);

  const titleEl = modal.querySelector("#appDialogTitle");
  const descEl = modal.querySelector("#appDialogDesc");
  const formEl = modal.querySelector("#appDialogForm");
  const labelEl = modal.querySelector("#appDialogLabel");
  const inputEl = modal.querySelector("#appDialogInput");
  const cancelBtn = modal.querySelector("#appDialogCancel");
  const confirmBtn = modal.querySelector("#appDialogConfirm");
  const backdrop = modal.querySelector(".confirm-modal-backdrop");
  const iconEl = modal.querySelector(".app-dialog-icon");

  let resolver = null;
  let focusReturn = null;
  let trapCleanup = null;
  let mode = "confirm";

  function close(result) {
    if (modal.style.display === "none") return;
    modal.style.display = "none";
    document.body.classList.remove("app-dialog-open");
    if (trapCleanup) {
      trapCleanup();
      trapCleanup = null;
    }
    const resolve = resolver;
    resolver = null;
    if (focusReturn && typeof focusReturn.focus === "function") {
      focusReturn.focus();
    }
    focusReturn = null;
    if (resolve) resolve(result);
  }

  function openConfirm(options = {}) {
    mode = "confirm";
    if (titleEl) titleEl.textContent = String(options.title || "Confirm action");
    if (descEl) descEl.textContent = String(options.description || "");
    if (formEl) formEl.classList.add("hidden");
    if (confirmBtn) {
      confirmBtn.textContent = String(options.confirmText || "Confirm");
      confirmBtn.classList.toggle("danger", Boolean(options.danger));
    }
    if (cancelBtn) cancelBtn.textContent = String(options.cancelText || "Cancel");
    if (iconEl) iconEl.classList.toggle("danger", Boolean(options.danger));

    focusReturn = document.activeElement;
    modal.style.display = "flex";
    document.body.classList.add("app-dialog-open");
    if (trapCleanup) trapCleanup();
    trapCleanup = trapModalFocus(modal);
    requestAnimationFrame(() => {
      if (confirmBtn) confirmBtn.focus();
    });

    return new Promise((resolve) => {
      resolver = resolve;
    });
  }

  function openPrompt(options = {}) {
    mode = "prompt";
    const multiline = options.multiline !== false;
    if (titleEl) titleEl.textContent = String(options.title || "Enter value");
    if (descEl) descEl.textContent = String(options.description || "");
    if (labelEl) labelEl.textContent = String(options.label || "Value");
    if (formEl) formEl.classList.remove("hidden");
    if (inputEl) {
      inputEl.value = String(options.defaultValue || "");
      inputEl.placeholder = String(options.placeholder || "");
      inputEl.maxLength = Number.isFinite(Number(options.maxLength))
        ? Math.max(1, Math.floor(Number(options.maxLength)))
        : 400;
      inputEl.rows = multiline ? 4 : 1;
      inputEl.classList.toggle("single-line", !multiline);
    }
    if (confirmBtn) {
      confirmBtn.textContent = String(options.confirmText || "Submit");
      confirmBtn.classList.toggle("danger", Boolean(options.danger));
    }
    if (cancelBtn) cancelBtn.textContent = String(options.cancelText || "Cancel");
    if (iconEl) iconEl.classList.toggle("danger", Boolean(options.danger));

    focusReturn = document.activeElement;
    modal.style.display = "flex";
    document.body.classList.add("app-dialog-open");
    if (trapCleanup) trapCleanup();
    trapCleanup = trapModalFocus(modal);
    requestAnimationFrame(() => {
      if (inputEl) {
        inputEl.focus();
        const len = inputEl.value.length;
        inputEl.setSelectionRange(len, len);
      }
    });

    return new Promise((resolve) => {
      resolver = resolve;
    });
  }

  if (cancelBtn) {
    cancelBtn.addEventListener("click", () => close(null));
  }
  if (confirmBtn) {
    confirmBtn.addEventListener("click", () => {
      if (mode === "prompt") {
        close(inputEl ? inputEl.value : "");
        return;
      }
      close(true);
    });
  }
  if (backdrop) {
    backdrop.addEventListener("click", () => close(null));
  }
  modal.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      event.preventDefault();
      close(null);
      return;
    }
    if (event.key === "Enter" && mode === "prompt" && inputEl && inputEl.classList.contains("single-line")) {
      event.preventDefault();
      close(inputEl.value);
    }
  });

  return {
    openConfirm,
    openPrompt,
  };
})();

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Username suggestions Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

function clearUsernameSuggestions() {
  if (!usernameHint || !usernameSuggestions) return;
  usernameHint.textContent = "";
  usernameHint.classList.add("hidden");
  usernameSuggestions.innerHTML = "";
  usernameSuggestions.classList.add("hidden");
}

function showUsernameSuggestions(requested, suggestions) {
  if (!usernameHint || !usernameSuggestions) return;
  const list = Array.isArray(suggestions) ? suggestions.slice(0, 6) : [];

  usernameHint.textContent = `"${requested}" is taken. Try one of these:`;
  usernameHint.classList.remove("hidden");
  usernameSuggestions.innerHTML = "";

  for (const suggestion of list) {
    const btn      = document.createElement("button");
    btn.type       = "button";
    btn.className  = "suggestion-chip";
    btn.textContent = suggestion;
    btn.addEventListener("click", () => {
      usernameInput.value = suggestion;
      usernameInput.focus();
      clearUsernameSuggestions();
    });
    usernameSuggestions.appendChild(btn);
  }

  usernameSuggestions.classList.toggle("hidden", list.length === 0);
}

function clearFriendSuggestions() {
  if (!friendSuggestions) return;
  friendSuggestions.innerHTML = "";
  friendSuggestions.classList.add("hidden");
}

function showFriendSuggestions(requested, suggestions) {
  if (!friendSuggestions) return;
  const list = Array.isArray(suggestions) ? suggestions.slice(0, 8) : [];
  friendSuggestions.innerHTML = "";
  for (const suggestion of list) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "friend-suggestion-item";

    const avatar = document.createElement("span");
    avatar.className = "friend-suggestion-avatar";
    avatar.textContent = suggestion.slice(0, 2).toUpperCase();

    const label = document.createElement("span");
    label.textContent = suggestion;

    btn.append(avatar, label);
    btn.addEventListener("click", () => {
      if (friendInput) {
        friendInput.value = suggestion;
        friendInput.focus();
      }
      clearFriendSuggestions();
    });
    friendSuggestions.appendChild(btn);
  }
  friendSuggestions.classList.toggle("hidden", list.length === 0 || !requested);
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Time formatting Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

function prettyTime(iso) {
  if (!iso) return "";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function formatFriendTime(iso) {
  if (!iso) return "";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  const now = new Date();
  if (date.toDateString() === now.toDateString()) {
    return prettyTime(iso);
  }
  return date.toLocaleDateString([], { month: "short", day: "numeric" });
}

function formatAudioTime(seconds) {
  const safe = Number.isFinite(seconds) ? Math.max(0, seconds) : 0;
  const mins = Math.floor(safe / 60);
  const secs = Math.floor(safe % 60);
  return `${mins}:${String(secs).padStart(2, "0")}`;
}

function getAudioDuration(audio) {
  if (!audio) return 0;
  const dur = audio.duration;
  if (Number.isFinite(dur) && dur > 0) return dur;
  if (audio.seekable && audio.seekable.length) {
    try {
      const end = audio.seekable.end(audio.seekable.length - 1);
      if (Number.isFinite(end) && end > 0) return end;
    } catch (_) {
      // Ignore seekable errors.
    }
  }
  return 0;
}

const VOICE_MIME_CANDIDATES = [
  "audio/webm;codecs=opus",
  "audio/webm",
  "audio/mp4",
  "audio/aac",
  "audio/ogg;codecs=opus",
  "audio/ogg",
  "audio/mpeg",
];
const VOICE_EXTENSION_BY_MIME = {
  "audio/webm": ".webm",
  "audio/wav": ".wav",
  "audio/mpeg": ".mp3",
  "audio/ogg": ".ogg",
  "audio/mp4": ".m4a",
  "audio/aac": ".aac",
};

function getSupportedVoiceMimeType() {
  if (typeof MediaRecorder === "undefined" || typeof MediaRecorder.isTypeSupported !== "function") {
    return "";
  }
  for (const candidate of VOICE_MIME_CANDIDATES) {
    if (MediaRecorder.isTypeSupported(candidate)) return candidate;
  }
  return "";
}

function getVoiceFileExtension(mimeType = "") {
  const normalized = String(mimeType || "").toLowerCase().split(";")[0].trim();
  return VOICE_EXTENSION_BY_MIME[normalized] || ".webm";
}

const WAVE_BAR_COUNT = 28;
const WAVE_BAR_MIN = 4;
const WAVE_BAR_MAX = 24;

function hashStringToSeed(value) {
  const str = String(value || "");
  let h = 2166136261;
  for (let i = 0; i < str.length; i += 1) {
    h ^= str.charCodeAt(i);
    h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
  }
  return h >>> 0;
}

function seededRng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t ^= t + Math.imul(t ^ (t >>> 7), 61 | t);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function buildWaveform(waveformEl, seed) {
  if (!waveformEl) return;
  const rng = seededRng(seed);
  waveformEl.innerHTML = "";
  for (let i = 0; i < WAVE_BAR_COUNT; i += 1) {
    const bar = document.createElement("span");
    bar.className = "wv-bar pending";
    const height = Math.round(WAVE_BAR_MIN + rng() * (WAVE_BAR_MAX - WAVE_BAR_MIN));
    bar.style.height = `${height}px`;
    waveformEl.appendChild(bar);
  }
}

function updateWaveformProgress(waveformEl, progress) {
  if (!waveformEl) return;
  const bars = waveformEl.querySelectorAll(".wv-bar");
  const played = Math.round(Math.max(0, Math.min(1, progress)) * bars.length);
  bars.forEach((bar, i) => {
    if (i < played) {
      bar.classList.add("played");
      bar.classList.remove("pending");
    } else {
      bar.classList.add("pending");
      bar.classList.remove("played");
    }
  });
}

function formatCallDuration(totalSeconds) {
  const safe = Number.isFinite(totalSeconds) ? Math.max(0, Math.floor(totalSeconds)) : 0;
  const hours = Math.floor(safe / 3600);
  const minutes = Math.floor((safe % 3600) / 60);
  const seconds = safe % 60;
  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  }
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}

function buildCallLogPayload(status, direction, durationSeconds, mediaType) {
  const safeStatus = String(status || "").trim() || "ended";
  const safeDirection = String(direction || "").trim() || "outgoing";
  const safeDuration = Number.isFinite(durationSeconds) ? Math.max(0, Math.floor(durationSeconds)) : 0;
  const safeMedia = String(mediaType || "").trim() || "audio";
  return `${CALL_LOG_PREFIX}${safeStatus}|${safeDirection}|${safeDuration}|${safeMedia}`;
}

function parseCallLogPayload(rawText) {
  const text = String(rawText || "");
  if (!text.startsWith(CALL_LOG_PREFIX)) return null;
  const body = text.slice(CALL_LOG_PREFIX.length);
  const [status, direction, duration, mediaType] = body.split("|");
  if (!status) return null;
  const seconds = Number.isFinite(Number(duration)) ? Math.max(0, Math.floor(Number(duration))) : 0;
  return {
    status: String(status || "").trim() || "ended",
    direction: String(direction || "").trim() || "outgoing",
    duration: seconds,
    mediaType: String(mediaType || "").trim() || "audio",
  };
}

function getCallHistoryStorageKey() {
  const userKey = normalizeName(me || "");
  return userKey ? `${CALL_HISTORY_KEY}:${userKey}` : CALL_HISTORY_KEY;
}

function readCallHistoryCache() {
  const key = getCallHistoryStorageKey();
  try {
    const raw = localStorage.getItem(key);
    const parsed = JSON.parse(raw || "[]");
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

function writeCallHistoryCache(list) {
  const key = getCallHistoryStorageKey();
  try {
    localStorage.setItem(key, JSON.stringify(list.slice(0, MAX_CALL_HISTORY)));
  } catch (_) {}
}

function addCallHistoryEntry(entry) {
  if (!entry || !entry.friend || !entry.text) return false;
  if (!me) return false;
  const list = readCallHistoryCache();
  const entryId = entry.id
    ? String(entry.id)
    : `${normalizeName(entry.friend)}|${entry.timestamp || ""}|${entry.text}`;
  if (list.some((item) => item._id === entryId)) return false;
  list.unshift({
    _id: entryId,
    friend: entry.friend,
    text: entry.text,
    timestamp: entry.timestamp || "",
    from: entry.from || "",
  });
  writeCallHistoryCache(list);
  return true;
}

function cacheCallLogMessage(message) {
  const log = parseCallLogPayload(message?.text);
  if (!log) return false;
  const other = normalizeName(message?.from) === normalizeName(me) ? message?.to : message?.from;
  const friend = String(other || "").trim();
  if (!friend) return false;
  return addCallHistoryEntry({
    id: message.id,
    friend,
    text: message.text,
    timestamp: message.timestamp || "",
    from: message.from || "",
  });
}

function cacheCallLogMessages(messages) {
  if (!Array.isArray(messages)) return;
  messages.forEach((msg) => cacheCallLogMessage(msg));
}

function invertCallDirection(direction) {
  if (direction === "outgoing") return "incoming";
  if (direction === "incoming") return "outgoing";
  return direction || "outgoing";
}

function getCallLogDisplay(log, fromMe) {
  const direction = fromMe ? log.direction : invertCallDirection(log.direction);
  const isVideo = log.mediaType === "video";
  const mediaLabel = isVideo ? "Video call" : "Call";
  const title = direction === "incoming"
    ? (isVideo ? "Incoming video" : "Incoming call")
    : (isVideo ? "Outgoing video" : "Outgoing call");
  let subtitle = mediaLabel;
  let statusLabel = "Ended";
  const isIncoming = direction === "incoming";
  if (log.status === "ended") {
    subtitle = log.duration > 0 ? `${mediaLabel} ended - ${formatCallDuration(log.duration)}` : `${mediaLabel} ended`;
    statusLabel = "Ended";
  } else if (log.status === "cancelled") {
    subtitle = isIncoming ? `Missed ${mediaLabel.toLowerCase()}` : `${mediaLabel} cancelled`;
    statusLabel = "Cancelled";
  } else if (log.status === "declined") {
    subtitle = isIncoming ? `Missed ${mediaLabel.toLowerCase()}` : `${mediaLabel} declined`;
    statusLabel = "Declined";
  } else if (log.status === "missed") {
    subtitle = `Missed ${mediaLabel.toLowerCase()}`;
    statusLabel = "Missed";
  } else if (log.status === "busy") {
    subtitle = isIncoming ? `Missed ${mediaLabel.toLowerCase()}` : "User busy";
    statusLabel = "Busy";
  } else if (log.status === "blocked") {
    subtitle = "Blocked by safety settings";
    statusLabel = "Blocked";
  } else if (log.status === "unavailable") {
    subtitle = isIncoming ? `Missed ${mediaLabel.toLowerCase()}` : "User unavailable";
    statusLabel = "Unavailable";
  }
  return { title, subtitle, direction, status: log.status, statusLabel };
}

function getCallMediaIconSvg(mediaType = "audio") {
  if (String(mediaType || "").trim().toLowerCase() === "video") {
    return `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M23 7l-7 5 7 5V7z"/><rect x="1" y="5" width="15" height="14" rx="2"/></svg>`;
  }
  return `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12a19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 3.6 1.18h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L7.91 8.96a16 16 0 0 0 6 6l.92-.92a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 21.73 16.92z"/></svg>`;
}

function getCallDirectionBadgeSvg(direction = "outgoing", statusClass = "neutral") {
  const incoming = normalizeName(direction) === "incoming";
  const badgeClass = incoming
    ? (statusClass === "bad" ? "in" : "ok")
    : "out";
  const badgePath = incoming
    ? "M7 1 L1 7 M5 7 L1 7 L1 3"
    : "M1 7 L7 1 M3 1 L7 1 L7 5";
  return `<span class="call-dir-badge ${badgeClass}" aria-hidden="true"><svg viewBox="0 0 8 8"><path d="${badgePath}"/></svg></span>`;
}

function formatCallLogPreview(rawText, fromMe) {
  const log = parseCallLogPayload(rawText);
  if (!log) return "";
  const display = getCallLogDisplay(log, fromMe);
  return `[Call] ${display.subtitle}`;
}

function formatLastSeen(iso) {
  if (!iso) return "Offline";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "Offline";

  const now = new Date();
  const timeText = date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  if (date.toDateString() === now.toDateString()) {
    return `Last seen ${timeText}`;
  }

  const y = new Date(now);
  y.setDate(now.getDate() - 1);
  if (date.toDateString() === y.toDateString()) {
    return `Last seen yesterday ${timeText}`;
  }

  const dateText = date.toLocaleDateString([], { month: "short", day: "numeric" });
  return `Last seen ${dateText}, ${timeText}`;
}

function cleanDisplayName(value) {
  return normalizeMojibakeText(value).trim();
}

function getMyDisplayName() {
  const display = cleanDisplayName(myProfile.displayName);
  if (display) return display;
  return me ? `@${me}` : "@you";
}

function renderMyName() {
  if (!meName) return;
  meName.textContent = getMyDisplayName();
  meName.title = me ? `@${me}` : "";
}

function getFriendDisplayName(friend) {
  const fallback = String(friend?.username || "").trim();
  const display = cleanDisplayName(friend?.displayName);
  return display || fallback;
}

function displayDiffersFromUsername(friend) {
  const username = String(friend?.username || "").trim();
  const display = cleanDisplayName(friend?.displayName);
  return Boolean(display) && normalizeName(display) !== normalizeName(username);
}

function getFriendPresenceText(friend) {
  if (normalizeChatKind(friend?.kind || "friend") === "group") {
    const members = Number(friend?.memberCount) || 0;
    const online = Number(friend?.onlineCount) || 0;
    if (online > 0) return `${online} online - ${members} members`;
    return `${members} member${members === 1 ? "" : "s"}`;
  }
  if (friend?.blockedByMe) return "Blocked by you";
  if (friend?.blockedYou) return "Blocked you";
  const mode = resolveFriendPresenceMode(friend);
  if (mode === "away") return "Away";
  if (mode === "busy") return "Busy";
  if (mode === "online") return "Online now";
  return formatLastSeen(friend.lastSeenAt);
}

function getContactBucket(friend) {
  const mode = resolveFriendPresenceMode(friend);
  if (mode === "online") return "online";
  if (mode === "away") return "away";
  if (mode === "busy") return "busy";
  return "offline";
}

function syncProfilePanelStats() {
  if (!profileStatMessages || !profileStatMedia || !profileStatLinks || !profileStatFiles) return;
  const messages = Array.isArray(conversationMessages) ? conversationMessages : [];
  const linkRegex = /(?:https?:\/\/|www\.)[^\s<]+/i;
  const mediaRegex = /\.(png|jpe?g|gif|webp|mp4|mov|webm|mp3|wav|ogg)(\?|#|$)/i;
  const fileRegex = /\.(pdf|zip|rar|7z|docx?|pptx?|xlsx?)(\?|#|$)/i;

  let linkCount = 0;
  let mediaCount = 0;
  let fileCount = 0;
  let visibleMessageCount = 0;

  for (const message of messages) {
    if (message?.deletedAt) continue;
    visibleMessageCount += 1;
    const text = String(message?.text || "");
    const attachment = normalizeAttachmentPayload(message?.attachment, text);
    if (text && linkRegex.test(text)) linkCount += 1;
    if ((attachment && attachment.kind === "image") || (text && mediaRegex.test(text))) mediaCount += 1;
    if ((attachment && attachment.kind === "file") || (text && fileRegex.test(text))) fileCount += 1;
  }

  profileStatMessages.textContent = String(visibleMessageCount);
  profileStatLinks.textContent = String(linkCount);
  profileStatMedia.textContent = String(mediaCount);
  profileStatFiles.textContent = String(fileCount);
}

function extractFirstUrlFromText(value) {
  const text = String(value || "").trim();
  if (!text) return "";
  const webMatch = text.match(/(?:https?:\/\/|www\.)[^\s<]+/i);
  if (webMatch && webMatch[0]) {
    const candidate = webMatch[0];
    return /^https?:\/\//i.test(candidate) ? candidate : `https://${candidate}`;
  }
  const uploadMatch = text.match(/(?:^|\s)(\.?\/?uploads\/[^\s<]+)/i);
  if (uploadMatch && uploadMatch[1]) {
    return normalizeAttachmentUrl(uploadMatch[1]);
  }
  const bareFileMatch = text.match(/(?:^|\s)([a-z0-9][a-z0-9._-]*\.(?:png|jpe?g|gif|webp|bmp|svg|mp4|mov|webm|mp3|wav|ogg|m4a|aac|pdf|txt|csv|zip|rar|7z|docx?|pptx?|xlsx?)(?:[?#][^\s<]*)?)/i);
  if (bareFileMatch && bareFileMatch[1]) {
    return normalizeAttachmentUrl(bareFileMatch[1]);
  }
  return "";
}

function syncInfoMediaGrid() {
  if (!infoMediaGrid) return;
  if (!activeFriend) {
    infoMediaGrid.innerHTML = '<div class="media-grid-empty">No shared media yet</div>';
    return;
  }

  const items = [];
  for (const message of (conversationMessages || []).slice().reverse()) {
    if (message?.deletedAt) continue;
    const text = String(message?.text || "").trim();
    const attachment = normalizeAttachmentPayload(message?.attachment, text);

    if (attachment && attachment.kind === "image") {
      items.push({
        type: "image",
        url: attachment.url || text,
        name: attachment.name || "Image attachment",
      });
      continue;
    }
    if (attachment && attachment.kind === "file") {
      items.push({
        type: "file",
        url: attachment.url || text,
        name: attachment.name || "Attachment",
        mime: attachment.mime || "",
        size: attachment.size || 0,
      });
      continue;
    }
    const url = extractFirstUrlFromText(text);
    if (url) {
      if (isLikelyAttachmentUrl(url)) {
        const legacyAttachment = normalizeAttachmentPayload({ url }, url);
        if (legacyAttachment?.kind === "image") {
          items.push({
            type: "image",
            url: legacyAttachment.url,
            name: legacyAttachment.name || "Image attachment",
          });
        } else if (legacyAttachment) {
          items.push({
            type: "file",
            url: legacyAttachment.url,
            name: legacyAttachment.name || "Attachment",
            mime: legacyAttachment.mime || "",
            size: legacyAttachment.size || 0,
          });
        }
      } else {
        items.push({
          type: "link",
          url,
          name: url,
        });
      }
    }
    if (items.length >= INFO_MEDIA_PREVIEW_LIMIT) break;
  }

  if (!items.length) {
    infoMediaGrid.innerHTML = '<div class="media-grid-empty">No shared media yet</div>';
    return;
  }

  infoMediaGrid.innerHTML = "";
  items.slice(0, INFO_MEDIA_PREVIEW_LIMIT).forEach((item) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = `media-thumb media-thumb-${item.type}`;
    btn.title = item.name;
    btn.setAttribute("aria-label", item.name);

    if (item.type === "image") {
      const img = document.createElement("img");
      img.src = item.url;
      img.alt = item.name;
      img.loading = "lazy";
      img.decoding = "async";
      btn.appendChild(img);
      btn.addEventListener("click", () => {
        imageViewer.open({
          src: item.url,
          fileName: item.name,
        });
      });
      infoMediaGrid.appendChild(btn);
      return;
    }

    btn.textContent = item.type === "link" ? "LINK" : "FILE";
    btn.addEventListener("click", () => {
      if (item.type === "link") {
        openExternalLink(item.url);
        return;
      }
      fileViewer.open({
        src: item.url,
        fileName: item.name,
        mime: item.mime || "",
        size: item.size || 0,
      });
    });
    infoMediaGrid.appendChild(btn);
  });
}

function syncCallLogPanel() {
  if (!callLogList) return;
  if (!activeFriend) {
    callLogList.innerHTML = '<div class="call-log-empty">No calls yet</div>';
    return;
  }
  const messages = Array.isArray(conversationMessages) ? conversationMessages : [];
  const logs = messages.filter((msg) => parseCallLogPayload(msg?.text));
  if (!logs.length) {
    callLogList.innerHTML = '<div class="call-log-empty">No calls yet</div>';
    return;
  }

  callLogList.innerHTML = "";
  const sortedLogs = logs
    .slice()
    .sort((a, b) => getTimestampSortValue(b?.timestamp || "") - getTimestampSortValue(a?.timestamp || ""));
  const recentLogs = sortedLogs.slice(0, 12);
  let lastDateKey = "";

  recentLogs.forEach((message) => {
      const log = parseCallLogPayload(message.text);
      if (!log) return;
      const timestamp = message.timestamp || "";
      const dateKey = getLocalDateKey(timestamp) || "unknown";
      if (dateKey !== lastDateKey) {
        lastDateKey = dateKey;
        callLogList.appendChild(createCallHistorySeparator("div", timestamp));
      }
      const fromMe = normalizeName(message.from) === normalizeName(me);
      const display = getCallLogDisplay(log, fromMe);

      const item = document.createElement("div");

      const icon = document.createElement("div");
      icon.className = "call-log-item-icon";

      const content = document.createElement("div");
      content.className = "call-log-item-content";
      const title = document.createElement("div");
      title.className = "call-log-item-title";
      title.textContent = display.title;
      const subtitle = document.createElement("div");
      subtitle.className = "call-log-item-subtitle";
      subtitle.textContent = display.subtitle;
      const isBadStatus = isBadCallStatus(display.status);
      const isNeutralStatus = display.status === "ended";
      const statusClass = isNeutralStatus ? "neutral" : (isBadStatus ? "bad" : "good");
      const mediaClass = log.mediaType === "video" ? "video" : "voice";
      item.className = `call-log-item ${display.direction === "incoming" ? "incoming" : "outgoing"} status-${statusClass} ${mediaClass}`;
      icon.innerHTML = `${getCallMediaIconSvg(log.mediaType)}${getCallDirectionBadgeSvg(display.direction, statusClass)}`;
      if (isBadStatus) subtitle.classList.add("is-alert");
      content.append(title, subtitle);

      const time = document.createElement("div");
      time.className = "call-log-item-time";
      time.textContent = prettyTime(timestamp);

      const actionBtn = document.createElement("button");
      actionBtn.type = "button";
      actionBtn.className = "call-log-action";
      actionBtn.title = "Call back";
      actionBtn.innerHTML = getCallMediaIconSvg("audio");
      actionBtn.addEventListener("click", (e) => {
        e.stopPropagation();
        startVoiceCall();
      });

      item.addEventListener("click", () => startVoiceCall());
      item.append(icon, content, time, actionBtn);
      callLogList.appendChild(item);
    });

  renderCallHistory();
}

function syncProfilePanel(friend) {
  if (!profilePanel || !profilePanelName || !profilePanelAvatar || !profilePanelHandle || !profilePanelStatus) return;

  if (!activeFriend) {
    profilePanelName.textContent = "Select a conversation";
    profilePanelHandle.textContent = "@handle";
    profilePanelStatus.textContent = "Offline";
    profilePanelStatus.classList.add("offline");
    profilePanelAvatar.textContent = "?";
    profilePanelAvatar.style.background = "";
    syncProfilePanelStats();
    syncInfoMediaGrid();
    syncSafetyActionButtons();
    return;
  }

  const resolvedFriend = friend || getActiveChatEntry();
  if (!resolvedFriend) {
    profilePanelName.textContent = "Loading...";
    profilePanelHandle.textContent = normalizeChatKind(activeChatKind) === "group" ? `#${activeFriend}` : `@${activeFriend}`;
    profilePanelStatus.textContent = "Loading status...";
    profilePanelStatus.classList.add("offline");
    profilePanelAvatar.textContent = activeFriend.slice(0, 2).toUpperCase();
    profilePanelAvatar.style.background = "";
    syncProfilePanelStats();
    syncInfoMediaGrid();
    syncSafetyActionButtons();
    return;
  }

  profilePanelName.textContent = getFriendDisplayName(resolvedFriend);
  const isGroup = normalizeChatKind(resolvedFriend.kind || activeChatKind) === "group";
  profilePanelHandle.textContent = isGroup ? `#${resolvedFriend.username}` : `@${resolvedFriend.username}`;
  const safety = getFriendSafety(resolvedFriend.username, resolvedFriend.kind || activeChatKind);
  const presenceMode = resolveFriendPresenceMode(resolvedFriend);
  if (isGroup) {
    const members = Number(resolvedFriend.memberCount) || 0;
    const online = Number(resolvedFriend.onlineCount) || 0;
    profilePanelStatus.textContent = online > 0 ? `${online} online` : `${members} members`;
  } else if (safety.blockedByMe) {
    profilePanelStatus.textContent = "Blocked by you";
  } else if (safety.blockedYou) {
    profilePanelStatus.textContent = "Blocked you";
  } else {
    profilePanelStatus.textContent = presenceMode === "away"
      ? "Away"
      : presenceMode === "busy"
        ? "Busy"
        : presenceMode === "online"
          ? "Active now"
          : formatLastSeen(resolvedFriend.lastSeenAt);
  }
  profilePanelStatus.classList.remove("online", "away", "busy", "offline", "me");
  if (isGroup) {
    const groupOnline = Number(resolvedFriend.onlineCount) > 0;
    profilePanelStatus.classList.add(groupOnline ? "online" : "offline");
  } else if (safety.blocked) {
    profilePanelStatus.classList.add("offline");
  } else {
    profilePanelStatus.classList.add(presenceMode);
  }

  const fallback = getFriendDisplayName(resolvedFriend).slice(0, 2).toUpperCase();
  if (resolvedFriend.avatarId && window._novynAvatarUtils) {
    window._novynAvatarUtils.applyAvatarToEl(
      profilePanelAvatar,
      resolvedFriend.avatarId,
      fallback
    );
  } else {
    profilePanelAvatar.style.background = "";
    profilePanelAvatar.textContent = fallback;
  }

  syncProfilePanelStats();
  syncInfoMediaGrid();
  syncSafetyActionButtons();
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Typing indicator Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

function showTypingIndicator(username) {
  if (!typingIndicator || !typingText) return;
  const displayName = username ? getFriendDisplayName(findFriend(username) || { username }) : "";
  typingText.textContent = displayName ? `${displayName} is typing...` : "Typing...";
  typingIndicator.classList.remove("hidden");
  if (typingAvatar) {
    typingAvatar.textContent = displayName ? displayName.slice(0, 1).toUpperCase() : "?";
  }
  if (isNearBottom()) scrollToBottom(true);
}

function hideTypingIndicator() {
  if (!typingIndicator) return;
  typingIndicator.classList.add("hidden");
}

function showSpeakingIndicator(peer) {
  if (!speakingIndicator || !speakingText) return;
  const source = String(arguments[1]?.source || "voice-note").trim() || "voice-note";
  // Keep this chip dedicated to voice-note activity, never live call audio.
  if (source === "call") return;
  const displayName = getCallPeerDisplayName(peer || callState.peer);
  speakingText.textContent = displayName ? `${displayName} is speaking...` : "Speaking...";
  if (speakingAvatar) {
    speakingAvatar.textContent = displayName ? displayName.slice(0, 1).toUpperCase() : "?";
  }
  speakingIndicator.dataset.source = source;
  speakingIndicatorState.source = source;
  speakingIndicator.classList.remove("hidden");
  if (isNearBottom()) scrollToBottom(true);
}

function hideSpeakingIndicator(source = "") {
  if (!speakingIndicator) return;
  const requiredSource = String(source || "").trim();
  const currentSource = String(speakingIndicator.dataset.source || speakingIndicatorState.source || "").trim();
  if (requiredSource && currentSource && requiredSource !== currentSource) return;
  speakingIndicator.classList.add("hidden");
  if (!requiredSource || requiredSource === currentSource) {
    speakingIndicator.dataset.source = "";
    speakingIndicatorState.source = "none";
  }
}

function emitTyping(isTyping, target = activeFriend, targetKind = activeChatKind) {
  const kind = normalizeChatKind(targetKind);
  const resolvedTarget = resolveOutgoingTarget(target, kind);
  if (!resolvedTarget) return;
  socket.emit("typing", { to: resolvedTarget, toType: kind, isTyping });
}

function emitVoiceActivity(isSpeaking, target = activeFriend, targetKind = activeChatKind) {
  if (!socketAvailable) return;
  const kind = normalizeChatKind(targetKind);
  const resolvedTarget = resolveOutgoingTarget(target, kind);
  if (!resolvedTarget) return;
  socket.emit("voice_activity", {
    to: resolvedTarget,
    toType: kind,
    isSpeaking: Boolean(isSpeaking),
  });
}

function clearLocalTypingTimer() {
  if (localTyping.timeoutId) {
    clearTimeout(localTyping.timeoutId);
    localTyping.timeoutId = null;
  }
}

function stopLocalTyping(target = localTyping.target || activeFriend, targetKind = localTyping.kind || activeChatKind) {
  if (localTyping.active && target) emitTyping(false, target, targetKind);
  localTyping.active    = false;
  localTyping.target    = "";
  localTyping.kind      = "friend";
  clearLocalTypingTimer();
}

function scheduleLocalTypingStop() {
  clearLocalTypingTimer();
  localTyping.timeoutId = setTimeout(() => stopLocalTyping(), 1200);
}

function markLocalTyping() {
  if (!activeFriend) return;

  // If switched to a different friend while typing, stop the old indicator
  if (
    localTyping.active &&
    localTyping.target &&
    (
      normalizeName(localTyping.target) !== normalizeName(activeFriend) ||
      normalizeChatKind(localTyping.kind) !== normalizeChatKind(activeChatKind)
    )
  ) {
    stopLocalTyping(localTyping.target, localTyping.kind);
  }

  if (!localTyping.active) emitTyping(true, activeFriend, activeChatKind);

  localTyping.active = true;
  localTyping.target = activeFriend;
  localTyping.kind = normalizeChatKind(activeChatKind);
  scheduleLocalTypingStop();
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Messages Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

function clearMessages() {
  messagesEl.innerHTML = "";
}

function getLastRenderedDateKey() {
  for (let i = messagesEl.children.length - 1; i >= 0; i -= 1) {
    const node = messagesEl.children[i];
    if (!node) continue;
    if (node.classList.contains("message-date-separator") && node.dataset.dateKey) {
      return node.dataset.dateKey;
    }
    if (node.classList.contains("message") && node.dataset.dateKey) {
      return node.dataset.dateKey;
    }
  }
  return "";
}

function appendDateSeparator(iso) {
  const dateKey = getLocalDateKey(iso);
  if (!dateKey) return;

  const previousKey = getLastRenderedDateKey();
  if (previousKey === dateKey) return;

  const separator = document.createElement("div");
  separator.className = "message-date-separator";
  separator.dataset.dateKey = dateKey;
  separator.textContent = formatDateSeparatorLabel(iso);
  messagesEl.appendChild(separator);
}

function getSearchQuery() {
  return normalizeSearchText(messageSearchInput ? messageSearchInput.value : "");
}

function getSearchScope() {
  if (!messageSearchScope) return "chat";
  return messageSearchScope.value === "global" ? "global" : "chat";
}

function getSearchFilter() {
  if (!messageSearchFilter) return "all";
  const allowed = new Set(["all", "media", "links", "files", "unread"]);
  const raw = String(messageSearchFilter.value || "").toLowerCase();
  return allowed.has(raw) ? raw : "all";
}

function renderGlobalSearchResults() {
  if (!globalSearchResults) return;
  const scope = getSearchScope();
  globalSearchResults.classList.toggle("hidden", scope !== "global");
  if (scope !== "global") {
    globalSearchResults.innerHTML = "";
    return;
  }

  const query = getSearchQuery();
  if (!query && getSearchFilter() === "all") {
    globalSearchResults.innerHTML = '<div class="global-search-empty">Type to search across chats.</div>';
    return;
  }
  if (query.length > 0 && query.length < GLOBAL_SEARCH_MIN_QUERY_LENGTH && getSearchFilter() === "all") {
    globalSearchResults.innerHTML = `<div class="global-search-empty">Type at least ${GLOBAL_SEARCH_MIN_QUERY_LENGTH} characters.</div>`;
    return;
  }

  if (globalSearchState.loading) {
    globalSearchResults.innerHTML = '<div class="global-search-empty">Searching...</div>';
    return;
  }

  const list = Array.isArray(globalSearchState.results) ? globalSearchState.results : [];
  if (!list.length) {
    globalSearchResults.innerHTML = '<div class="global-search-empty">No results found.</div>';
    return;
  }

  globalSearchResults.innerHTML = "";
  list.forEach((hit) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "global-search-item";

    const title = document.createElement("div");
    title.className = "global-search-item-title";
    const label = String(hit?.withDisplayName || hit?.with || "").trim() || "Unknown";
    const prefix = hit?.mine ? "You: " : "";
    title.textContent = label;

    const body = document.createElement("div");
    body.className = "global-search-item-body";
    body.textContent = `${prefix}${String(hit?.text || "").trim()}`.slice(0, 160);

    const meta = document.createElement("div");
    meta.className = "global-search-item-meta";
    const when = prettyTime(hit?.timestamp || "");
    meta.textContent = hit?.unread ? `${when} - unread` : when;

    btn.append(title, body, meta);
    btn.addEventListener("click", () => {
      const target = String(hit?.with || "").trim();
      const messageId = String(hit?.messageId || "").trim();
      const kind = normalizeChatKind(hit?.kind || "friend");
      if (!target) return;
      pendingMessageFocus = { friendKey: normalizeName(target), messageId, kind };
      setActiveFriend(target, kind);
      showChatOnMobile();
    });

    globalSearchResults.appendChild(btn);
  });
}

function requestGlobalSearch() {
  if (!socketAvailable || !socket) return;
  const query = getSearchQuery();
  const filter = getSearchFilter();
  if (query.length > 0 && query.length < GLOBAL_SEARCH_MIN_QUERY_LENGTH && filter === "all") {
    globalSearchState.loading = false;
    globalSearchState.results = [];
    renderGlobalSearchResults();
    if (messageSearchCount) {
      messageSearchCount.classList.remove("hidden");
      messageSearchCount.textContent = `0 results`;
    }
    return;
  }
  globalSearchState.query = query;
  globalSearchState.filter = filter;
  globalSearchState.loading = true;
  const requestId = globalSearchState.requestId + 1;
  globalSearchState.requestId = requestId;
  renderGlobalSearchResults();

  if (globalSearchState.timer) {
    clearTimeout(globalSearchState.timer);
  }
  globalSearchState.timer = setTimeout(() => {
    socket.emit("global_search_messages", {
      query: messageSearchInput ? messageSearchInput.value.trim() : "",
      filter,
      limit: 120,
      requestId,
    });
  }, 160);
}

function syncMessageSearchUi() {
  const queryActive = Boolean(getSearchQuery());
  const scope = getSearchScope();

  if (messageSearchPanel) {
    messageSearchPanel.classList.toggle("hidden", !searchPanelOpen);
  }

  if (messageSearchToggle) {
    messageSearchToggle.classList.toggle("active", queryActive || searchPanelOpen);
    messageSearchToggle.setAttribute("aria-expanded", searchPanelOpen ? "true" : "false");
    messageSearchToggle.title = queryActive ? "Search active" : "Search messages";
  }

  if (messageSearchPrev) messageSearchPrev.classList.toggle("hidden", scope !== "chat");
  if (messageSearchNext) messageSearchNext.classList.toggle("hidden", scope !== "chat");
  if (messageSearchFilter) messageSearchFilter.classList.toggle("hidden", scope !== "global");

  renderGlobalSearchResults();
}

function openMessageSearchPanel() {
  if (!messageSearchPanel) return;
  searchPanelOpen = true;
  syncMessageSearchUi();
  if (messageSearchInput) {
    messageSearchInput.focus();
    messageSearchInput.select();
  }
  applyMessageSearch();
}

function closeMessageSearchPanel() {
  searchPanelOpen = false;
  if (globalSearchState.timer) {
    clearTimeout(globalSearchState.timer);
    globalSearchState.timer = null;
  }
  syncMessageSearchUi();
}

function shouldAutoScrollForMessage(message, skipAnimation = false) {
  if (skipAnimation) return true;
  if (getSearchQuery()) return false;

  if (!message) {
    return scrollState.pinnedToBottom || isNearBottom();
  }

  const mine = normalizeName(message.from) === normalizeName(me);
  if (mine) return true;

  return scrollState.pinnedToBottom || isNearBottom();
}

function resetMessageSearch() {
  if (messageSearchInput) messageSearchInput.value = "";
  if (messageSearchScope) messageSearchScope.value = "chat";
  if (messageSearchFilter) messageSearchFilter.value = "all";
  globalSearchState.results = [];
  globalSearchState.loading = false;
  if (globalSearchState.timer) {
    clearTimeout(globalSearchState.timer);
    globalSearchState.timer = null;
  }
  closeMessageSearchPanel();
  applyMessageSearch();
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function highlightText(text, query) {
  if (!query) return escapeHtml(text);
  const source = String(text || "");
  const lower = source.toLowerCase();
  const needle = String(query || "").toLowerCase();
  if (!needle) return escapeHtml(source);
  let result = "";
  let start = 0;
  while (true) {
    const idx = lower.indexOf(needle, start);
    if (idx === -1) {
      result += escapeHtml(source.slice(start));
      break;
    }
    result += escapeHtml(source.slice(start, idx));
    result += `<mark class="msg-highlight">${escapeHtml(source.slice(idx, idx + needle.length))}</mark>`;
    start = idx + needle.length;
  }
  return result;
}

function updateMessageHighlight(row, query) {
  if (!row) return;
  if (row.classList.contains("call-log") || row.classList.contains("message-deleted")) return;
  if (row.dataset.hasAttachment === "1") {
    const body = row.querySelector(".message-body");
    if (body && !body.querySelector(".msg-img, .file-bubble")) {
      const messageId = row.dataset.messageId || "";
      const tempId = row.dataset.clientTempId || "";
      const source = messageId
        ? getConversationMessageById(messageId)
        : (tempId ? pendingByTempId.get(tempId) : null);
      if (source) {
        const replacement = buildMessageElement(source, true);
        row.replaceWith(replacement);
      }
    }
    return;
  }
  const body = row.querySelector(".message-body");
  if (!body || body.querySelector(".audio-card")) return;
  const raw = body.dataset.rawText || row.dataset.messageText || "";
  if (!body.dataset.rawText) body.dataset.rawText = raw;
  if (!query) {
    body.innerHTML = "";
    appendMessageTextWithLinks(body, raw);
    return;
  }
  body.innerHTML = highlightText(raw, query);
}

function clearSearchFocus() {
  for (const hit of searchState.hits) {
    hit.classList.remove("search-focus");
  }
}

function setSearchFocus(index, scroll = true) {
  if (!searchState.hits.length) return;
  clearSearchFocus();
  const safeIndex = Math.max(0, Math.min(searchState.hits.length - 1, index));
  searchState.index = safeIndex;
  const target = searchState.hits[safeIndex];
  if (target) {
    target.classList.add("search-focus");
    if (scroll) {
      target.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }
}

function jumpSearchResult(delta) {
  if (getSearchScope() !== "chat") return;
  if (!searchState.hits.length) return;
  const next = searchState.index + delta;
  if (next < 0) {
    setSearchFocus(searchState.hits.length - 1);
  } else if (next >= searchState.hits.length) {
    setSearchFocus(0);
  } else {
    setSearchFocus(next);
  }
}

function updateSearchNavButtons() {
  const chatMode = getSearchScope() === "chat";
  const hasHits = searchState.hits.length > 0;
  if (messageSearchPrev) messageSearchPrev.disabled = !chatMode || !hasHits;
  if (messageSearchNext) messageSearchNext.disabled = !chatMode || !hasHits;
}

function applyMessageSearch() {
  const query = getSearchQuery();
  const scope = getSearchScope();
  const messageNodes = Array.from(messagesEl.querySelectorAll("article.message"));
  let visibleCount = 0;
  const previousQuery = searchState.query;

  if (scope === "global") {
    searchState.hits = [];
    searchState.index = -1;
    searchState.query = query;
    clearSearchFocus();

    for (const row of messageNodes) {
      row.classList.remove("search-hidden");
      updateMessageHighlight(row, "");
    }
    const separatorNodes = Array.from(messagesEl.querySelectorAll(".message-date-separator"));
    separatorNodes.forEach((node) => node.classList.remove("search-hidden"));

    const filter = getSearchFilter();
    if (!query && filter === "all") {
      globalSearchState.results = [];
      globalSearchState.loading = false;
      if (messageSearchCount) {
        messageSearchCount.classList.add("hidden");
        messageSearchCount.textContent = "";
      }
      renderGlobalSearchResults();
    } else {
      requestGlobalSearch();
      if (messageSearchCount) {
        messageSearchCount.classList.remove("hidden");
        messageSearchCount.textContent = globalSearchState.loading
          ? "Searching..."
          : `${globalSearchState.results.length} result${globalSearchState.results.length === 1 ? "" : "s"}`;
      }
    }

    updateSearchNavButtons();
    syncMessageSearchUi();
    return;
  }

  if (globalSearchState.timer) {
    clearTimeout(globalSearchState.timer);
    globalSearchState.timer = null;
  }
  globalSearchState.loading = false;

  searchState.hits = [];
  searchState.query = query;
  if (previousQuery !== query) {
    searchState.index = -1;
    clearSearchFocus();
  }

  for (const row of messageNodes) {
    const searchable = normalizeSearchText(
      row.dataset.searchText || `${row.dataset.messageText || ""} ${row.dataset.messageFrom || ""}`
    );
    const match = !query || searchable.includes(query);
    row.classList.toggle("search-hidden", !match);
    if (match) {
      visibleCount += 1;
      if (query) searchState.hits.push(row);
    }
    updateMessageHighlight(row, query && match ? query : "");
  }

  const separatorNodes = Array.from(messagesEl.querySelectorAll(".message-date-separator"));
  for (const separator of separatorNodes) {
    let hasVisibleMessages = false;
    let cursor = separator.nextElementSibling;
    while (cursor && !cursor.classList.contains("message-date-separator")) {
      if (cursor.classList.contains("message") && !cursor.classList.contains("search-hidden")) {
        hasVisibleMessages = true;
        break;
      }
      cursor = cursor.nextElementSibling;
    }
    separator.classList.toggle("search-hidden", Boolean(query) && !hasVisibleMessages);
  }

  if (messageSearchCount) {
    if (!query) {
      messageSearchCount.classList.add("hidden");
      messageSearchCount.textContent = "";
    } else {
      const total = messageNodes.length;
      messageSearchCount.classList.remove("hidden");
      messageSearchCount.textContent = `${visibleCount}/${total} match${visibleCount === 1 ? "" : "es"}`;
    }
  }

  updateSearchNavButtons();
  syncMessageSearchUi();
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Reply UI Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

const replyBanner = (() => {
  const existing = document.getElementById("replyBanner");
  const banner = existing || document.createElement("div");
  if (!existing) {
    banner.id = "replyBanner";
    banner.className = "reply-banner hidden";
  }
  let preview = banner.querySelector(".reply-preview-text");
  if (!preview) {
    preview = document.createElement("span");
    preview.className = "reply-preview-text";
    banner.appendChild(preview);
  }
  let closeBtn = banner.querySelector(".reply-cancel-btn");
  if (!closeBtn) {
    closeBtn = document.createElement("button");
    closeBtn.type = "button";
    closeBtn.className = "reply-cancel-btn";
    closeBtn.innerHTML = "&times;";
    banner.appendChild(closeBtn);
  }
  closeBtn.addEventListener("click", clearReply);
  banner.addEventListener("click", (e) => {
    if (e.target.closest(".reply-cancel-btn")) return;
    if (replyTo && replyTo.id) focusMessageById(replyTo.id);
  });
  if (!existing && messageForm && messageForm.parentNode) {
    messageForm.parentNode.insertBefore(banner, messageForm);
  }
  return { banner, preview };
})();

function setReply(message) {
  replyTo = { id: message.id, from: message.from, text: message.text };
  const raw = String(message.text || "").replace(/\s+/g, " ").trim();
  const snippet = raw.length > 70 ? `${raw.slice(0, 70)}...` : raw;
  replyBanner.preview.textContent = `Replying: "${snippet}"`;
  replyBanner.banner.dataset.replyId = message.id || "";
  replyBanner.banner.classList.remove("hidden");
  messageInput.focus();
}

function clearReply() {
  replyTo = null;
  replyBanner.banner.classList.add("hidden");
  replyBanner.preview.textContent = "";
  replyBanner.banner.dataset.replyId = "";
}

function getConversationMessageById(messageId) {
  if (!messageId) return null;
  return conversationMessages.find((message) => message?.id === messageId) || null;
}

function getRepliesForMessage(messageId) {
  if (!messageId) return [];
  return (conversationMessages || [])
    .filter((message) => message && !message.deletedAt && message.replyTo?.id === messageId)
    .sort((a, b) => String(a?.timestamp || "").localeCompare(String(b?.timestamp || "")));
}

function countRepliesForMessage(messageId) {
  return getRepliesForMessage(messageId).length;
}

const threadDialog = (() => {
  const modal = document.createElement("div");
  modal.className = "thread-modal hidden";
  modal.innerHTML = `
    <div class="thread-backdrop"></div>
    <div class="thread-card" role="dialog" aria-modal="true" aria-label="Message thread">
      <div class="thread-head">
        <span class="thread-title">Thread</span>
        <button type="button" class="thread-close" aria-label="Close thread">&times;</button>
      </div>
      <div class="thread-root"></div>
      <div class="thread-list"></div>
    </div>
  `;
  document.body.appendChild(modal);
  const backdrop = modal.querySelector(".thread-backdrop");
  const closeBtn = modal.querySelector(".thread-close");
  const rootEl = modal.querySelector(".thread-root");
  const listEl = modal.querySelector(".thread-list");

  function close() {
    modal.classList.add("hidden");
    if (listEl) listEl.innerHTML = "";
    if (rootEl) rootEl.innerHTML = "";
  }

  function open(rootMessage, replies) {
    if (!rootEl || !listEl) return;
    const rootText = String(rootMessage?.text || "").trim() || "(message)";
    const rootFrom = String(rootMessage?.from || "").trim() || "Unknown";
    rootEl.innerHTML = `
      <div class="thread-root-from">${rootFrom}</div>
      <div class="thread-root-text">${rootText}</div>
    `;

    listEl.innerHTML = "";
    replies.forEach((reply) => {
      const row = document.createElement("button");
      row.type = "button";
      row.className = "thread-item";
      const from = String(reply?.from || "").trim() || "Unknown";
      const text = String(reply?.text || "").trim() || "(message)";
      row.innerHTML = `
        <span class="thread-item-from">${from}</span>
        <span class="thread-item-text">${text}</span>
        <span class="thread-item-time">${prettyTime(reply?.timestamp || "")}</span>
      `;
      row.addEventListener("click", () => {
        close();
        focusMessageById(reply.id);
      });
      listEl.appendChild(row);
    });
    modal.classList.remove("hidden");
  }

  if (backdrop) backdrop.addEventListener("click", close);
  if (closeBtn) closeBtn.addEventListener("click", close);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !modal.classList.contains("hidden")) {
      close();
    }
  });

  return { open, close };
})();

function openThreadForMessage(messageId) {
  const rootMessage = getConversationMessageById(messageId);
  if (!rootMessage) return;
  const replies = getRepliesForMessage(messageId);
  if (!replies.length) {
    showToast("No replies yet.", "info");
    return;
  }
  threadDialog.open(rootMessage, replies);
}

function getMessagePeerUsername(message) {
  if (!message) return "";
  const kind = normalizeChatKind(message.toType || (message.groupId ? "group" : "friend"));
  if (kind === "group") {
    return String(message.groupId || message.toKey || activeFriend || "").trim();
  }
  const from = String(message.from || "").trim();
  const to = String(message.to || "").trim();
  if (!from && !to) return activeFriend || "";
  if (normalizeName(from) === normalizeName(me)) {
    return to || activeFriend || "";
  }
  return from || activeFriend || "";
}

function summarizeMessageForPinnedBar(message) {
  if (!message) return "Pinned message";
  const attachment = normalizeAttachmentPayload(message.attachment, message.text || "");
  if (attachment) {
    const prefix = attachment.kind === "image" ? "Image" : "File";
    const suffix = attachment.name ? `: ${attachment.name}` : "";
    return `${prefix}${suffix}`;
  }
  const raw = String(message.text || "").replace(/\s+/g, " ").trim();
  if (!raw) return "Pinned message";
  return raw.length > 96 ? `${raw.slice(0, 96)}...` : raw;
}

function getDisplayNameForReactionUser(rawName) {
  const value = String(rawName || "").trim();
  if (!value) return "";
  const key = normalizeName(value);
  if (key && key === normalizeName(me)) return "You";
  const friend = findFriend(value) || friends.find((entry) => normalizeName(entry?.username) === key);
  if (friend) {
    return cleanDisplayName(friend.displayName) || friend.username || value;
  }
  return value;
}

const messageEditDialog = (() => {
  const modal = document.createElement("div");
  modal.id = "messageEditModal";
  modal.className = "confirm-modal";
  modal.style.display = "none";
  modal.innerHTML = `
    <div class="confirm-modal-backdrop"></div>
    <div class="confirm-modal-card settings-modal-card message-edit-card">
      <h3>Edit message</h3>
      <p class="confirm-modal-desc">Update your message for everyone in this chat.</p>
      <textarea id="messageEditInput" class="message-edit-input" maxlength="${COMPOSER_MAX_MESSAGE_LENGTH}" rows="4"></textarea>
      <div class="confirm-modal-btns">
        <button type="button" class="confirm-modal-cancel" data-edit-action="cancel">Cancel</button>
        <button type="button" class="settings-confirm" data-edit-action="save">Save</button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);

  const input = modal.querySelector("#messageEditInput");
  const backdrop = modal.querySelector(".confirm-modal-backdrop");
  const cancelBtn = modal.querySelector('[data-edit-action="cancel"]');
  const saveBtn = modal.querySelector('[data-edit-action="save"]');
  let onSave = null;
  let originalText = "";

  function close() {
    modal.style.display = "none";
    onSave = null;
    originalText = "";
    if (input) input.value = "";
  }

  function save() {
    if (!onSave || !input) return;
    if (!String(input.value || "").trim()) {
      showToast("Message cannot be empty.", "error");
      return;
    }
    const validated = validateOutgoingMessageText(input.value);
    if (validated === null || !validated) return;
    if (validated === originalText) {
      close();
      return;
    }
    onSave(validated);
    close();
  }

  if (backdrop) backdrop.addEventListener("click", close);
  if (cancelBtn) cancelBtn.addEventListener("click", close);
  if (saveBtn) saveBtn.addEventListener("click", save);
  if (input) {
    input.addEventListener("keydown", (event) => {
      if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
        event.preventDefault();
        save();
      }
    });
  }
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && modal.style.display !== "none") {
      close();
    }
  });

  function open(initialText, handler) {
    if (!input) return;
    originalText = String(initialText || "").trim();
    onSave = typeof handler === "function" ? handler : null;
    input.value = originalText;
    modal.style.display = "flex";
    setTimeout(() => {
      input.focus();
      input.setSelectionRange(input.value.length, input.value.length);
    }, 0);
  }

  return { open, close };
})();

const reactionDetailsDialog = (() => {
  const modal = document.createElement("div");
  modal.id = "reactionDetailsModal";
  modal.className = "confirm-modal";
  modal.style.display = "none";
  modal.innerHTML = `
    <div class="confirm-modal-backdrop"></div>
    <div class="confirm-modal-card settings-modal-card reaction-details-card">
      <h3>Reactions</h3>
      <div id="reactionDetailsList" class="reaction-details-list"></div>
      <div class="confirm-modal-btns">
        <button type="button" class="settings-confirm" data-reaction-action="close">Close</button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);

  const list = modal.querySelector("#reactionDetailsList");
  const closeBtn = modal.querySelector('[data-reaction-action="close"]');
  const backdrop = modal.querySelector(".confirm-modal-backdrop");

  function close() {
    modal.style.display = "none";
    if (list) list.innerHTML = "";
  }

  function open(reactionGroups) {
    if (!list) return;
    list.innerHTML = "";
    reactionGroups.forEach((entry) => {
      const section = document.createElement("section");
      section.className = "reaction-details-group";
      const title = document.createElement("div");
      title.className = "reaction-details-title";
      title.textContent = `${entry.emoji} ${entry.count}`;

      const users = document.createElement("ul");
      users.className = "reaction-details-users";

      entry.users.forEach((name) => {
        const item = document.createElement("li");
        item.textContent = name;
        users.appendChild(item);
      });

      if (entry.extraCount > 0) {
        const item = document.createElement("li");
        item.className = "reaction-details-more";
        item.textContent = `and ${entry.extraCount} more`;
        users.appendChild(item);
      }

      section.append(title, users);
      list.appendChild(section);
    });
    modal.style.display = "flex";
  }

  if (closeBtn) closeBtn.addEventListener("click", close);
  if (backdrop) backdrop.addEventListener("click", close);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && modal.style.display !== "none") {
      close();
    }
  });

  return { open, close };
})();

const messageForwardDialog = (() => {
  const modal = document.createElement("div");
  modal.id = "messageForwardModal";
  modal.className = "confirm-modal";
  modal.style.display = "none";
  modal.innerHTML = `
    <div class="confirm-modal-backdrop"></div>
    <div class="confirm-modal-card settings-modal-card message-forward-card">
      <h3>Forward message</h3>
      <p class="confirm-modal-desc">Choose a friend to forward this message to.</p>
      <div id="messageForwardPreview" class="message-forward-preview"></div>
      <div id="messageForwardList" class="message-forward-list"></div>
      <div class="confirm-modal-btns">
        <button type="button" class="confirm-modal-cancel" data-forward-action="cancel">Cancel</button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);

  const list = modal.querySelector("#messageForwardList");
  const preview = modal.querySelector("#messageForwardPreview");
  const cancelBtn = modal.querySelector('[data-forward-action="cancel"]');
  const backdrop = modal.querySelector(".confirm-modal-backdrop");
  let sourceMessage = null;
  let sending = false;

  function close() {
    sending = false;
    modal.style.display = "none";
    if (list) list.innerHTML = "";
    if (preview) preview.textContent = "";
    sourceMessage = null;
  }

  function forwardTo(friendUsername) {
    if (!sourceMessage || !friendUsername || sending) return;
    const attachment = normalizeAttachmentPayload(sourceMessage.attachment, sourceMessage.text || "");
    const payload = {
      to: friendUsername,
      text: String(sourceMessage.text || "").trim(),
    };
    if (attachment) payload.attachment = attachment;
    if (!payload.text) {
      showToast("Nothing to forward.", "error");
      return;
    }
    sending = true;
    if (cancelBtn) cancelBtn.disabled = true;
    const sentTempId = sendMessagePayload(payload, { optimistic: false });
    if (!sentTempId) {
      sending = false;
      if (cancelBtn) cancelBtn.disabled = false;
      return;
    }
    if (socketAvailable && socket.connected) {
      showToast(`Forwarded to @${friendUsername}`, "success");
    }
    close();
  }

  function open(message) {
    if (!list) return;
    sourceMessage = message && typeof message === "object" ? message : null;
    if (!sourceMessage) return;
    list.innerHTML = "";
    sending = false;
    if (cancelBtn) cancelBtn.disabled = false;
    if (preview) {
      preview.textContent = summarizeMessageForPinnedBar(sourceMessage);
    }

    const availableFriends = friends
      .filter((friend) => friend && friend.username)
      .sort((a, b) => getFriendDisplayName(a).localeCompare(getFriendDisplayName(b)));

    if (!availableFriends.length) {
      const empty = document.createElement("div");
      empty.className = "message-forward-empty";
      empty.textContent = "No friends available.";
      list.appendChild(empty);
      modal.style.display = "flex";
      return;
    }

    availableFriends.forEach((friend) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "message-forward-btn";
      const displayName = getFriendDisplayName(friend);
      const nameEl = document.createElement("span");
      nameEl.className = "message-forward-name";
      nameEl.textContent = displayName;
      const handleEl = document.createElement("span");
      handleEl.className = "message-forward-handle";
      handleEl.textContent = `@${friend.username}`;
      btn.append(nameEl, handleEl);
      btn.addEventListener("click", () => forwardTo(friend.username));
      list.appendChild(btn);
    });

    modal.style.display = "flex";
  }

  if (cancelBtn) cancelBtn.addEventListener("click", close);
  if (backdrop) backdrop.addEventListener("click", close);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && modal.style.display !== "none") {
      close();
    }
  });

  return { open, close };
})();

const pinnedMessageBar = (() => {
  const bar = document.createElement("div");
  bar.id = "pinnedMessageBar";
  bar.className = "pinned-message-bar hidden";
  bar.innerHTML = `
    <button type="button" class="pinned-message-main">
      <span class="pinned-message-label">Pinned</span>
      <span class="pinned-message-text"></span>
    </button>
    <button type="button" class="pinned-message-clear" title="Unpin message" aria-label="Unpin message">&times;</button>
  `;

  if (messageSearchPanel && messageSearchPanel.parentNode) {
    if (messageSearchPanel.nextSibling) {
      messageSearchPanel.parentNode.insertBefore(bar, messageSearchPanel.nextSibling);
    } else {
      messageSearchPanel.parentNode.appendChild(bar);
    }
  } else if (messagesEl?.parentNode) {
    messagesEl.parentNode.insertBefore(bar, messagesEl.parentNode.firstChild);
  }

  const mainBtn = bar.querySelector(".pinned-message-main");
  const textEl = bar.querySelector(".pinned-message-text");
  const clearBtn = bar.querySelector(".pinned-message-clear");
  let currentMessageId = "";
  let currentPeer = "";
  let currentKind = "friend";

  function clear() {
    currentMessageId = "";
    currentPeer = "";
    currentKind = "friend";
    bar.classList.add("hidden");
    if (textEl) textEl.textContent = "";
  }

  function set(message) {
    if (!message?.id) {
      clear();
      return;
    }
    currentMessageId = message.id;
    currentPeer = getMessagePeerUsername(message) || activeFriend || "";
    currentKind = normalizeChatKind(message?.toType || activeChatKind || "friend");
    if (textEl) {
      textEl.textContent = summarizeMessageForPinnedBar(message);
    }
    bar.classList.remove("hidden");
  }

  if (mainBtn) {
    mainBtn.addEventListener("click", () => {
      if (!currentMessageId) return;
      openPinnedMessagesDialog();
    });
  }
  if (clearBtn) {
    clearBtn.addEventListener("click", (event) => {
      event.stopPropagation();
      if (!currentMessageId || !currentPeer) return;
      socket.emit("set_message_pin", {
        messageId: currentMessageId,
        to: currentPeer,
        toType: currentKind,
        pinned: false,
      });
    });
  }

  return { set, clear };
})();

function getReactionGroupsForMessage(messageId) {
  const message = getConversationMessageById(messageId);
  if (!message || !message.reactions || typeof message.reactions !== "object") return [];

  const groups = [];
  for (const [emoji, rawEntry] of Object.entries(message.reactions)) {
    if (!rawEntry || typeof rawEntry !== "object") continue;
    const rawCount = Number(rawEntry.count);
    const fromUserKeys = Array.isArray(rawEntry.userKeys) ? rawEntry.userKeys : [];
    const fromUsers = Array.isArray(rawEntry.users) ? rawEntry.users : [];
    const count = Number.isFinite(rawCount) && rawCount > 0
      ? Math.floor(rawCount)
      : Math.max(fromUserKeys.length, fromUsers.length);
    if (!count) continue;

    const uniqueNames = [];
    const seen = new Set();
    const combinedNames = fromUsers.length
      ? fromUsers
      : fromUserKeys.map((name) => getDisplayNameForReactionUser(name));
    combinedNames.forEach((rawName) => {
      const pretty = getDisplayNameForReactionUser(rawName);
      const key = normalizeName(pretty);
      if (!pretty || !key || seen.has(key)) return;
      seen.add(key);
      uniqueNames.push(pretty);
    });

    if (rawEntry.mine && !uniqueNames.some((name) => normalizeName(name) === normalizeName("You"))) {
      uniqueNames.unshift("You");
    }

    groups.push({
      emoji,
      count,
      users: uniqueNames,
      extraCount: Math.max(0, count - uniqueNames.length),
    });
  }

  groups.sort((a, b) => b.count - a.count || a.emoji.localeCompare(b.emoji));
  return groups;
}

function openReactionDetailsForMessage(messageId) {
  const groups = getReactionGroupsForMessage(messageId);
  if (!groups.length) {
    showToast("No reactions yet.", "info");
    return;
  }
  reactionDetailsDialog.open(groups);
}

function syncPinnedMessageBar() {
  if (!activeFriend || !Array.isArray(conversationMessages) || !conversationMessages.length) {
    pinnedMessageBar.clear();
    return;
  }

  const pinned = conversationMessages
    .filter((message) => message && !message.deletedAt && message.pinnedAt)
    .sort((a, b) => {
      const aKey = String(a?.pinnedAt || a?.timestamp || "");
      const bKey = String(b?.pinnedAt || b?.timestamp || "");
      return bKey.localeCompare(aKey);
    });

  if (!pinned.length) {
    pinnedMessageBar.clear();
    return;
  }
  pinnedMessageBar.set(pinned[0]);
}

function getPinnedMessagesSorted() {
  return (conversationMessages || [])
    .filter((message) => message && !message.deletedAt && message.pinnedAt)
    .sort((a, b) => {
      const aKey = String(a?.pinnedAt || a?.timestamp || "");
      const bKey = String(b?.pinnedAt || b?.timestamp || "");
      return bKey.localeCompare(aKey);
    });
}

const pinnedMessagesDialog = (() => {
  const modal = document.createElement("div");
  modal.className = "pins-modal hidden";
  modal.innerHTML = `
    <div class="pins-backdrop"></div>
    <div class="pins-card" role="dialog" aria-modal="true" aria-label="Pinned messages">
      <div class="pins-head">
        <span class="pins-title">Pinned messages</span>
        <button type="button" class="pins-close" aria-label="Close pinned messages">&times;</button>
      </div>
      <div class="pins-list"></div>
    </div>
  `;
  document.body.appendChild(modal);
  const backdrop = modal.querySelector(".pins-backdrop");
  const closeBtn = modal.querySelector(".pins-close");
  const listEl = modal.querySelector(".pins-list");

  function close() {
    modal.classList.add("hidden");
    if (listEl) listEl.innerHTML = "";
  }

  function open(messages) {
    if (!listEl) return;
    listEl.innerHTML = "";
    messages.forEach((message) => {
      const row = document.createElement("div");
      row.className = "pins-item";

      const jump = document.createElement("button");
      jump.type = "button";
      jump.className = "pins-item-jump";
      jump.innerHTML = `
        <span class="pins-item-text">${summarizeMessageForPinnedBar(message)}</span>
        <span class="pins-item-meta">${prettyTime(message?.timestamp || "")}</span>
      `;
      jump.addEventListener("click", () => {
        close();
        focusMessageById(message.id);
      });

      const unpin = document.createElement("button");
      unpin.type = "button";
      unpin.className = "pins-item-unpin";
      unpin.textContent = "Unpin";
      unpin.addEventListener("click", () => {
        const target = getMessagePeerUsername(message);
        const targetType = normalizeChatKind(message?.toType || activeChatKind || "friend");
        socket.emit("set_message_pin", {
          messageId: message.id,
          to: target,
          toType: targetType,
          pinned: false,
        });
      });

      row.append(jump, unpin);
      listEl.appendChild(row);
    });
    modal.classList.remove("hidden");
  }

  if (backdrop) backdrop.addEventListener("click", close);
  if (closeBtn) closeBtn.addEventListener("click", close);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !modal.classList.contains("hidden")) {
      close();
    }
  });

  return { open, close };
})();

function openPinnedMessagesDialog() {
  const pinned = getPinnedMessagesSorted();
  if (!pinned.length) {
    showToast("No pinned messages in this chat.", "info");
    return;
  }
  if (pinned.length === 1) {
    focusMessageById(pinned[0].id);
    return;
  }
  pinnedMessagesDialog.open(pinned);
}

const messageContextMenu = (() => {
  const menu = document.createElement("div");
  menu.id = "messageContextMenu";
  menu.className = "message-context-menu hidden";
  menu.innerHTML = `
    <button type="button" data-action="copy">Copy</button>
    <button type="button" data-action="reply">Reply</button>
    <button type="button" data-action="thread">Thread</button>
    <button type="button" data-action="forward">Forward</button>
    <button type="button" data-action="react">React</button>
    <button type="button" data-action="reactions">Reactions</button>
    <button type="button" data-action="edit">Edit</button>
    <button type="button" data-action="pin">Pin</button>
    <button type="button" data-action="delete" class="danger">Delete</button>
  `;
  document.body.appendChild(menu);

  let currentMessageEl = null;

  function close() {
    menu.classList.add("hidden");
    currentMessageEl = null;
  }

  function getMessagePeer(msgEl) {
    const rowKind = normalizeChatKind(msgEl?.dataset?.messageKind || activeChatKind || "friend");
    if (rowKind === "group") {
      return { to: activeFriend, toType: "group" };
    }
    let target = String(msgEl?.dataset?.messageFrom || "").trim();
    if (normalizeName(target) === normalizeName(me)) {
      target = activeFriend;
    }
    return { to: target, toType: "friend" };
  }

  function open(msgEl, x, y) {
    if (!msgEl) return;
    currentMessageEl = msgEl;

    const mine = msgEl.classList.contains("me");
    const deleted = msgEl.classList.contains("message-deleted");
    const pending = msgEl.classList.contains("pending");
    const hasAttachment = msgEl.dataset.hasAttachment === "1";
    const isCallLog = msgEl.classList.contains("call-log");
    const hasReactions = Boolean(msgEl.dataset.messageReactions);
    const pinned = Boolean(msgEl.dataset.pinnedAt);
    const messageId = String(msgEl.dataset.messageId || "").trim();
    const deleteBtn = menu.querySelector('[data-action="delete"]');
    const copyBtn = menu.querySelector('[data-action="copy"]');
    const replyBtn = menu.querySelector('[data-action="reply"]');
    const threadBtn = menu.querySelector('[data-action="thread"]');
    const forwardBtn = menu.querySelector('[data-action="forward"]');
    const reactBtn = menu.querySelector('[data-action="react"]');
    const reactionsBtn = menu.querySelector('[data-action="reactions"]');
    const editBtn = menu.querySelector('[data-action="edit"]');
    const pinBtn = menu.querySelector('[data-action="pin"]');

    if (deleteBtn) deleteBtn.classList.toggle("hidden", !mine || deleted || pending || !messageId);
    if (copyBtn) copyBtn.classList.toggle("hidden", deleted);
    if (replyBtn) replyBtn.classList.toggle("hidden", deleted || pending || !messageId);
    if (threadBtn) threadBtn.classList.toggle("hidden", deleted || !messageId);
    if (forwardBtn) forwardBtn.classList.toggle("hidden", deleted || pending || !messageId);
    if (reactBtn) reactBtn.classList.toggle("hidden", deleted || pending || !messageId);
    if (reactionsBtn) reactionsBtn.classList.toggle("hidden", deleted || !messageId || !hasReactions);
    if (editBtn) editBtn.classList.toggle("hidden", !mine || deleted || pending || hasAttachment || isCallLog || !messageId);
    if (pinBtn) {
      pinBtn.classList.toggle("hidden", deleted || pending || !messageId);
      pinBtn.textContent = pinned ? "Unpin" : "Pin";
      pinBtn.dataset.pinState = pinned ? "unpin" : "pin";
    }

    menu.classList.remove("hidden");
    menu.style.left = "0px";
    menu.style.top = "0px";

    const rect = menu.getBoundingClientRect();
    const margin = 8;
    let left = x;
    let top = y;

    if (left + rect.width > window.innerWidth - margin) {
      left = window.innerWidth - rect.width - margin;
    }
    if (top + rect.height > window.innerHeight - margin) {
      top = window.innerHeight - rect.height - margin;
    }
    if (left < margin) left = margin;
    if (top < margin) top = margin;

    menu.style.left = `${left}px`;
    menu.style.top = `${top}px`;
  }

  menu.addEventListener("click", async (e) => {
    const actionBtn = e.target.closest("button[data-action]");
    if (!actionBtn || !currentMessageEl) return;

    const action = actionBtn.dataset.action;
    const messageId = currentMessageEl.dataset.messageId;
    const messageText = currentMessageEl.dataset.messageText || "";
    const targetPeer = getMessagePeer(currentMessageEl);

    if (action === "copy") {
      try {
        await navigator.clipboard.writeText(messageText);
        showToast("Message copied");
      } catch (_) {
        showToast("Could not copy message", "error");
      }
      close();
      return;
    }

    if (action === "reply") {
      setReply({
        id: messageId,
        from: currentMessageEl.dataset.messageFrom || "",
        text: messageText,
      });
      close();
      return;
    }

    if (action === "thread") {
      if (messageId) {
        openThreadForMessage(messageId);
      }
      close();
      return;
    }

    if (action === "forward") {
      if (!messageId) {
        close();
        return;
      }
      const sourceMessage = getConversationMessageById(messageId);
      close();
      if (!sourceMessage || sourceMessage.deletedAt) return;
      messageForwardDialog.open(sourceMessage);
      return;
    }

    if (action === "react") {
      const reactBtn = currentMessageEl.querySelector('[data-msg-action="react"]');
      if (reactBtn) reactBtn.click();
      close();
      return;
    }

    if (action === "reactions") {
      if (messageId) {
        openReactionDetailsForMessage(messageId);
      }
      close();
      return;
    }

    if (action === "edit") {
      if (!messageId || !targetPeer?.to) {
        close();
        return;
      }
      const sourceMessage = getConversationMessageById(messageId);
      const initialText = String(sourceMessage?.text || "").trim();
      close();
      if (!initialText) return;
      messageEditDialog.open(initialText, (nextText) => {
        socket.emit("edit_message", {
          messageId,
          to: targetPeer.to,
          toType: targetPeer.toType,
          text: nextText,
        });
      });
      return;
    }

    if (action === "pin") {
      if (!messageId || !targetPeer?.to) {
        close();
        return;
      }
      const shouldPin = actionBtn.dataset.pinState !== "unpin";
      socket.emit("set_message_pin", {
        messageId,
        to: targetPeer.to,
        toType: targetPeer.toType,
        pinned: shouldPin,
      });
      close();
      return;
    }

    if (action === "delete") {
      if (!messageId || !targetPeer?.to) {
        close();
        return;
      }
      socket.emit("delete_message", { messageId, to: targetPeer.to, toType: targetPeer.toType });
      close();
    }
  });

  document.addEventListener("click", (e) => {
    if (!e.target.closest("#messageContextMenu")) close();
  });
  window.addEventListener("resize", close);
  messagesEl.addEventListener("scroll", close, { passive: true });

  messagesEl.addEventListener("contextmenu", (e) => {
    const reactionBtn = e.target.closest(".reaction-btn");
    if (reactionBtn) {
      const reactionMessage = reactionBtn.closest("article.message");
      const reactionMessageId = String(reactionMessage?.dataset?.messageId || "").trim();
      if (reactionMessageId) {
        e.preventDefault();
        openReactionDetailsForMessage(reactionMessageId);
      }
      return;
    }
    const msgEl = e.target.closest("article.message");
    if (!msgEl) return;
    e.preventDefault();
    open(msgEl, e.clientX, e.clientY);
  });

  let longPressTimer = null;
  let longPressTarget = null;
  let longPressStartX = 0;
  let longPressStartY = 0;
  let swipeReplyPointerId = null;
  let swipeReplyTarget = null;
  let swipeReplyStartX = 0;
  let swipeReplyStartY = 0;
  let swipeReplyDragX = 0;
  let swipeReplyLocked = false;
  let swipeReplyHorizontal = false;
  const SWIPE_REPLY_TRIGGER_X = 58;
  const SWIPE_REPLY_MAX_X = 88;

  function triggerSwipeReplyHaptic() {
    try {
      const cap = window.Capacitor?.Plugins?.Haptics;
      if (cap && typeof cap.impact === "function") {
        cap.impact({ style: "light" });
        return;
      }
    } catch (_) {}
    if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
      navigator.vibrate(9);
    }
  }

  function isSwipeReplyGestureTarget(target) {
    if (!(target instanceof Element)) return false;
    if (target.closest("a, button, input, textarea, select")) return false;
    if (target.closest(".msg-action-btn, .reaction-btn, .reaction-picker")) return false;
    if (target.closest(".message-context-menu")) return false;
    if (target.closest(".audio-card, .audio-play, .wv-track, .wv-bar")) return false;
    if (target.closest(".message-thread-pill")) return false;
    return true;
  }

  function clearLongPress() {
    if (longPressTimer) clearTimeout(longPressTimer);
    longPressTimer = null;
    longPressTarget = null;
  }

  function clearSwipeReply(options = {}) {
    const resetTransform = options.resetTransform !== false;
    const prevTarget = swipeReplyTarget;
    swipeReplyPointerId = null;
    swipeReplyTarget = null;
    swipeReplyStartX = 0;
    swipeReplyStartY = 0;
    swipeReplyDragX = 0;
    swipeReplyLocked = false;
    swipeReplyHorizontal = false;
    if (!resetTransform || !prevTarget) return;
    prevTarget.classList.remove("swipe-ready");
    prevTarget.style.removeProperty("transform");
    prevTarget.style.removeProperty("transition");
  }

  messagesEl.addEventListener("pointerdown", (e) => {
    const msgEl = e.target.closest("article.message");
    if (!msgEl) return;
    if (e.pointerType === "mouse" && e.button !== 0) return;
    longPressTarget = msgEl;
    longPressStartX = e.clientX;
    longPressStartY = e.clientY;
    longPressTimer = setTimeout(() => {
      if (!longPressTarget) return;
      open(longPressTarget, longPressStartX, longPressStartY);
      clearLongPress();
    }, 520);

    clearSwipeReply();
    if (e.pointerType === "mouse") return;
    if (!isSwipeReplyGestureTarget(e.target)) return;
    swipeReplyPointerId = e.pointerId;
    swipeReplyTarget = msgEl;
    swipeReplyStartX = e.clientX;
    swipeReplyStartY = e.clientY;
    swipeReplyDragX = 0;
    swipeReplyLocked = false;
    swipeReplyHorizontal = false;
  });
  messagesEl.addEventListener("pointermove", (e) => {
    if (longPressTimer) {
      const dx = Math.abs(e.clientX - longPressStartX);
      const dy = Math.abs(e.clientY - longPressStartY);
      if (dx > 8 || dy > 8) clearLongPress();
    }

    if (!swipeReplyTarget) return;
    if (swipeReplyPointerId !== null && e.pointerId !== swipeReplyPointerId) return;

    const dragXRaw = e.clientX - swipeReplyStartX;
    const dragYRaw = e.clientY - swipeReplyStartY;
    if (!swipeReplyLocked) {
      if (Math.abs(dragXRaw) < 4 && Math.abs(dragYRaw) < 4) return;
      swipeReplyLocked = true;
      swipeReplyHorizontal = dragXRaw > 0 && Math.abs(dragXRaw) > (Math.abs(dragYRaw) * 1.08);
      if (!swipeReplyHorizontal) {
        clearSwipeReply();
        return;
      }
    }
    if (!swipeReplyHorizontal) return;

    const dragX = Math.max(0, Math.min(SWIPE_REPLY_MAX_X, dragXRaw));
    swipeReplyDragX = dragX;
    swipeReplyTarget.style.transition = "none";
    swipeReplyTarget.style.transform = `translateX(${dragX}px)`;
    swipeReplyTarget.classList.toggle("swipe-ready", dragX >= SWIPE_REPLY_TRIGGER_X);
    e.preventDefault();
  });
  messagesEl.addEventListener("pointerup", (e) => {
    if (swipeReplyTarget && (swipeReplyPointerId === null || e.pointerId === swipeReplyPointerId)) {
      const targetEl = swipeReplyTarget;
      const shouldReply = swipeReplyDragX >= SWIPE_REPLY_TRIGGER_X;
      const messageId = String(targetEl?.dataset?.messageId || "").trim();
      const sourceMessage = messageId ? getConversationMessageById(messageId) : null;

      targetEl.classList.remove("swipe-ready");
      targetEl.style.transition = "transform .18s ease";
      targetEl.style.transform = "";
      setTimeout(() => {
        targetEl.style.removeProperty("transition");
      }, 220);

      if (shouldReply && sourceMessage && !sourceMessage.deletedAt) {
        setReply({
          id: sourceMessage.id,
          from: sourceMessage.from,
          text: sourceMessage.text,
        });
        triggerSwipeReplyHaptic();
        targetEl.classList.add("swipe-fired");
        setTimeout(() => targetEl.classList.remove("swipe-fired"), 260);
      }

      clearSwipeReply({ resetTransform: false });
    } else {
      clearSwipeReply();
    }
    clearLongPress();
  });
  messagesEl.addEventListener("pointercancel", () => {
    clearSwipeReply();
    clearLongPress();
  });

  return { open, close };
})();

function renderMessagesEmptyState(text) {
  clearMessages();
  messageWindowStart = 0;
  messageWindowEnd = 0;
  loadOlderBtn = null;
  hideTypingIndicator();

  const hint = text || EMPTY_CONVERSATION_HINT;
  let title = "Your inbox is ready";

  if (/loading conversation/i.test(hint)) {
    title = "Opening conversation";
  } else if (/no messages yet/i.test(hint) && activeFriend) {
    title = `Start chatting with @${activeFriend}`;
  }

  const empty = document.createElement("div");
  empty.className = "messages-empty";

  const icon = document.createElement("div");
  icon.className = "messages-empty-icon";
  icon.setAttribute("aria-hidden", "true");
  icon.innerHTML = `
    <svg class="empty-portal-icon" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
      <g class="portal-ring-bg">
        <circle cx="24" cy="24" r="18" stroke="currentColor" stroke-width="7" stroke-opacity="0.08"/>
      </g>
      <g class="portal-outer">
        <circle cx="24" cy="24" r="18" stroke="currentColor" stroke-width="2.5" stroke-dasharray="28 85" stroke-linecap="round" fill="none"/>
      </g>
      <g class="portal-inner">
        <circle cx="24" cy="24" r="10" stroke="currentColor" stroke-width="1.8" stroke-dasharray="14 50" stroke-linecap="round" fill="none" opacity="0.45"/>
      </g>
      <g class="portal-dot">
        <circle cx="24" cy="24" r="3" fill="currentColor"/>
      </g>
    </svg>
  `;

  const titleEl = document.createElement("p");
  titleEl.className = "messages-empty-title";
  titleEl.textContent = title;

  const sub = document.createElement("p");
  sub.className = "messages-empty-sub";
  sub.textContent = hint;

  empty.append(icon, titleEl, sub);
  messagesEl.appendChild(empty);
  applyMessageSearch();
  syncPinnedMessageBar();
}

function renderMineMessageMeta(metaEl, timeText, statusKey) {
  metaEl.innerHTML = "";
  metaEl.classList.add("mine");
  metaEl.dataset.time = timeText;
  const normalizedStatus = ["pending", "sent", "delivered", "seen", "failed"].includes(statusKey) ? statusKey : "sent";
  metaEl.dataset.status = normalizedStatus;

  const time = document.createElement("span");
  time.className = "message-meta-time";
  time.textContent = timeText;

  const status = document.createElement("span");
  status.className = `message-status message-status-${normalizedStatus}`;
  const statusLabelMap = {
    pending: "Sending...",
    sent: "Sent",
    delivered: "Delivered",
    seen: "Seen",
    failed: "Failed to send",
  };
  const statusLabel = statusLabelMap[normalizedStatus] || "Sent";
  status.title = statusLabel;
  status.setAttribute("role", "img");
  status.setAttribute("aria-label", statusLabel);
  status.innerHTML = `
    <svg class="msg-status" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false">
      <circle class="portal-ring-bg" cx="8" cy="8" r="6.25" />
      <circle class="portal-ring" cx="8" cy="8" r="6.25" />
      <circle class="portal-center" cx="8" cy="8" r="1.6" />
      <path class="portal-cross" d="M5.85 5.85L10.15 10.15M10.15 5.85L5.85 10.15" />
    </svg>
  `;
  metaEl.append(time, status);
}

function renderIncomingMessageMeta(metaEl, message) {
  metaEl.classList.remove("mine");
  metaEl.innerHTML = "";
  const time = prettyTime(message.timestamp);
  metaEl.textContent = time;
}

function appendMessageTextWithLinks(container, text) {
  const raw = normalizeMojibakeText(text);
  const urlRegex = /(?:https?:\/\/)?(?:www\.)?[a-z0-9-]+(?:\.[a-z0-9-]+)+(?:[\/?#][^\s<]*)?/gi;
  const parts = raw.split(urlRegex);
  const matches = raw.match(urlRegex) || [];
  if (!matches.length) {
    container.textContent = raw;
    return;
  }
  for (let i = 0; i < parts.length; i += 1) {
    if (parts[i]) container.appendChild(document.createTextNode(parts[i]));
    if (matches[i]) {
      const link = document.createElement("a");
      link.className = "message-link";
      const href = /^https?:\/\//i.test(matches[i]) ? matches[i] : `https://${matches[i]}`;
      link.href = href;
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.textContent = matches[i];
      link.addEventListener("click", (e) => {
        if (e && e.preventDefault) e.preventDefault();
        if (e && e.stopPropagation) e.stopPropagation();
        openExternalLink(href);
      });
      container.appendChild(link);
    }
  }
}

function focusMessageById(messageId) {
  if (!messageId || !messagesEl) return;
  const orig = messagesEl.querySelector(`[data-message-id="${messageId}"]`);
  if (orig) {
    orig.scrollIntoView({ behavior: "smooth", block: "center" });
    orig.classList.add("highlight-flash");
    setTimeout(() => orig.classList.remove("highlight-flash"), 1200);
  }
}

function revealAndFocusMessage(messageId) {
  if (!messageId) return false;
  if (!Array.isArray(conversationMessages) || !conversationMessages.length) return false;
  const index = conversationMessages.findIndex((message) => message?.id === messageId);
  if (index < 0) return false;

  if (index < messageWindowStart || index >= messageWindowEnd) {
    messageWindowEnd = Math.min(conversationMessages.length, index + 1);
    messageWindowStart = Math.max(0, messageWindowEnd - MAX_VISIBLE_MESSAGES);
    renderMessageWindow({ skipSearch: true });
    applyMessageSearch();
  }

  focusMessageById(messageId);
  return true;
}

function buildMessageElement(message, skipAnimation = false) {
  const mine = normalizeName(message.from) === normalizeName(me);
  const isDeleted = Boolean(message.deletedAt);
  const rawText = isDeleted ? DELETED_MESSAGE_TEXT : message.text;
  const attachment = !isDeleted ? normalizeAttachmentPayload(message.attachment, rawText) : null;
  const callLog = !isDeleted ? parseCallLogPayload(rawText) : null;
  const labsMeta = !isDeleted ? getMessageLabsMeta(message) : {};
  const labsBranch = normalizeLabsBranch(labsMeta.branch || "");
  const labsIntent = normalizeLabsIntent(labsMeta.intent || "");
  const displayText = callLog ? formatCallLogPreview(rawText, mine) : rawText;
  const searchableText = attachment ? `${attachment.name || ""} ${attachment.url || rawText || ""}` : displayText;
  const dateKey = getLocalDateKey(message.timestamp);
  const fullTimestamp = formatFullTimestamp(message.timestamp);

  const row       = document.createElement("article");
  row.className   = `message ${mine ? "me" : "them"}${skipAnimation ? " no-anim" : ""}`;
  if (message.id) row.dataset.messageId = message.id;
  if (message.clientTempId) row.dataset.clientTempId = message.clientTempId;
  row.dataset.dateKey = dateKey;
  row.dataset.timestamp = message.timestamp || "";
  row.dataset.tsFull = fullTimestamp;
  if (fullTimestamp) row.title = fullTimestamp;
  row.dataset.messageFrom = message.from;
  row.dataset.messageKind = normalizeChatKind(message.toType || (message.groupId ? "group" : activeChatKind || "friend"));
  row.dataset.messageText = searchableText || "";
  row.dataset.searchText = [
    row.dataset.messageFrom,
    searchableText || "",
    message.replyTo?.text || "",
    message.replyTo?.from || "",
  ].join(" ");
  if (labsBranch) row.dataset.labsBranch = labsBranch;
  if (labsIntent) row.dataset.labsIntent = labsIntent;
  const branchFilter = getLabsBranchFilterForChat(getLabsChatKey(activeFriend, activeChatKind));
  const intentFilter = getLabsIntentFilterForChat(getLabsChatKey(activeFriend, activeChatKind));
  const branchVisible = !labsBranch || branchFilter === "all" || labsBranch === branchFilter;
  const intentVisible = !labsIntent || intentFilter === "all" || labsIntent === intentFilter;
  if (!branchVisible || !intentVisible) {
    row.classList.add("labs-filter-hidden");
  }
  if (attachment) {
    row.dataset.hasAttachment = "1";
  } else {
    delete row.dataset.hasAttachment;
  }
  if (!isDeleted && message.editedAt) {
    row.dataset.editedAt = String(message.editedAt);
  } else {
    delete row.dataset.editedAt;
  }
  if (!isDeleted && message.pinnedAt) {
    row.dataset.pinnedAt = String(message.pinnedAt);
    row.classList.add("message-pinned");
  } else {
    delete row.dataset.pinnedAt;
  }
  if (isDeleted) {
    row.classList.add("message-deleted");
  }
  if (message.pending) {
    row.classList.add("pending");
  }
  if (message.failed) {
    row.classList.add("failed");
  }
  if (callLog) {
    row.classList.add("call-log");
  }

  if (message.reactions && Object.keys(message.reactions).length) {
    try {
      row.dataset.messageReactions = JSON.stringify(message.reactions);
    } catch (_) {
      // Ignore serialization errors for malformed payloads.
    }
  } else {
    delete row.dataset.messageReactions;
  }

  if (!callLog) {
    const meta        = document.createElement("span");
    meta.className    = "message-meta";
    if (mine) {
      row.dataset.timeLabel = prettyTime(message.timestamp);
      renderMineMessageMeta(meta, row.dataset.timeLabel, getMessageStatusKey(message));
    } else {
      renderIncomingMessageMeta(meta, message);
    }
    if (!isDeleted && message.editedAt) {
      const editedFlag = document.createElement("span");
      editedFlag.className = "message-edited-flag";
      editedFlag.textContent = "edited";
      meta.appendChild(editedFlag);
    }
    if (!isDeleted && message.pinnedAt) {
      const pinnedFlag = document.createElement("span");
      pinnedFlag.className = "message-pinned-flag";
      pinnedFlag.textContent = "pinned";
      meta.appendChild(pinnedFlag);
    }
    row.append(meta);
  }

  if (message.replyTo && !isDeleted) {
    const rq      = document.createElement("div");
    rq.className  = "reply-quote";
    const rt      = document.createElement("span");
    rt.className  = "reply-quote-text";
    const replyText = String(message.replyTo?.text || "");
    rt.textContent = replyText.slice(0, 80) + (replyText.length > 80 ? "..." : "");
    rq.addEventListener("click", () => {
      focusMessageById(message.replyTo.id);
    });
    rq.append(rt);
    row.append(rq);
  }

  const rowKind = normalizeChatKind(message.toType || (message.groupId ? "group" : activeChatKind || "friend"));
  if (rowKind === "group" && !mine && !isDeleted) {
    const author = document.createElement("div");
    author.className = "message-author";
    author.textContent = message.from || "Member";
    row.append(author);
  }

  const body        = document.createElement("div");
  body.className    = "message-body";
  if (!isDeleted && (labsBranch || labsIntent || labsMeta.sensitive)) {
    const labsMetaRow = document.createElement("div");
    labsMetaRow.className = "message-labs-meta";
    if (labsBranch) {
      const branchChip = document.createElement("span");
      branchChip.className = "message-labs-chip branch";
      branchChip.textContent = `Branch: ${labsBranch}`;
      labsMetaRow.append(branchChip);
    }
    if (labsIntent) {
      const intentChip = document.createElement("span");
      intentChip.className = "message-labs-chip intent";
      intentChip.textContent = `Intent: ${labsIntent}`;
      labsMetaRow.append(intentChip);
    }
    if (labsMeta.sensitive) {
      const sensitiveChip = document.createElement("span");
      sensitiveChip.className = "message-labs-chip sensitive";
      sensitiveChip.textContent = "Sensitive";
      labsMetaRow.append(sensitiveChip);
    }
    row.append(labsMetaRow);
  }
  if (isDeleted) {
    body.textContent = DELETED_MESSAGE_TEXT;
    body.classList.add("message-body-deleted");
  } else {
    const trimmedText = String(message.text || "").trim();
    const attachmentUrl = attachment?.url || "";
    const audioPattern = /\.(webm|wav|mp3|ogg|m4a|aac)(\?.*)?$/i;
    const isAudioAttachment = Boolean(attachment) && (
      /^audio\//i.test(String(attachment?.mime || ""))
      || audioPattern.test(attachmentUrl || trimmedText)
    );
    const isAudio = isAudioAttachment || (!attachment && (
      /^\/uploads\/.+\.(webm|wav|mp3|ogg|m4a|aac)(\?.*)?$/i.test(trimmedText) ||
      /^https?:\/\/.+\.(webm|wav|mp3|ogg|m4a|aac)(\?.*)?$/i.test(trimmedText)
    ));
    if (attachment && attachment.kind === "image") {
      const img = document.createElement("img");
      img.className = "msg-img";
      img.src = attachmentUrl || trimmedText;
      img.alt = attachment.name || "Image attachment";
      img.loading = "lazy";
      img.decoding = "async";
      const keepPinnedAfterImageLoad = () => {
        if (isMessageViewportMutationActive()) return;
        if (!scrollState.pinnedToBottom && !isNearBottom()) return;
        pinConversationToBottom();
      };
      img.addEventListener("load", keepPinnedAfterImageLoad, { once: true });
      img.addEventListener("error", keepPinnedAfterImageLoad, { once: true });
      img.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        imageViewer.open({
          src: attachmentUrl || trimmedText,
          fileName: attachment.name || "Image attachment",
        });
      });
      body.appendChild(img);
      body.dataset.rawText = attachment.name || attachmentUrl || message.text || "";
    } else if (callLog) {
      const log = getCallLogDisplay(callLog, mine);
      const isBadStatus = isBadCallStatus(log.status);
      const isNeutralStatus = log.status === "ended";
      const statusClass = isNeutralStatus ? "neutral" : (isBadStatus ? "bad" : "good");
      const mediaClass = callLog.mediaType === "video" ? "video" : "voice";
      const card = document.createElement("div");
      card.className = `call-log-card ${log.direction === "incoming" ? "incoming" : "outgoing"} status-${statusClass} ${mediaClass}`;

      const icon = document.createElement("div");
      icon.className = "call-log-icon";
      icon.innerHTML = `${getCallMediaIconSvg(callLog.mediaType)}${getCallDirectionBadgeSvg(log.direction, statusClass)}`;

      const content = document.createElement("div");
      content.className = "call-log-content";
      const title = document.createElement("div");
      title.className = "call-log-title";
      title.textContent = log.title;
      const subtitle = document.createElement("div");
      subtitle.className = "call-log-subtitle";
      subtitle.textContent = log.subtitle;
      const subRow = document.createElement("div");
      subRow.className = "call-log-subrow";
      if (isBadStatus) subtitle.classList.add("is-alert");
      subRow.append(subtitle);
      content.append(title, subRow);

      const time = document.createElement("div");
      time.className = "call-log-time";
      time.textContent = prettyTime(message.timestamp);
      const right = document.createElement("div");
      right.className = "call-log-right";
      right.append(time);

      card.append(icon, content, right);
      body.appendChild(card);
      body.dataset.rawText = message.text || "";
    } else if (isAudio) {
      body.classList.add("message-audio");
      const audioCard = document.createElement("div");
      audioCard.className = "audio-card";

      const playBtn = document.createElement("button");
      playBtn.type = "button";
      playBtn.className = "audio-play";
      playBtn.setAttribute("aria-label", "Play voice message");
      playBtn.innerHTML = `
        <svg class="icon-play" viewBox="0 0 24 24" aria-hidden="true"><polygon points="8 5 19 12 8 19 8 5"/></svg>
        <svg class="icon-pause" viewBox="0 0 24 24" aria-hidden="true"><rect x="6" y="5" width="4" height="14"/><rect x="14" y="5" width="4" height="14"/></svg>
      `;

      const waveform = document.createElement("div");
      waveform.className = "audio-waveform";
      const seedValue = message.id || message.clientTempId || message.timestamp || trimmedText;
      buildWaveform(waveform, hashStringToSeed(seedValue));

      const time = document.createElement("span");
      time.className = "audio-time";
      time.textContent = "0:00 / 0:00";

      const audio = document.createElement("audio");
      audio.className = "audio-el";
      audio.preload = "metadata";
      audio.src = attachmentUrl || trimmedText;
      audio.setAttribute("playsinline", "");

      const syncUI = () => {
        const cur = audio.currentTime || 0;
        const dur = getAudioDuration(audio);
        time.textContent = `${formatAudioTime(cur)} / ${formatAudioTime(dur)}`;
        const pct = dur > 0 ? (cur / dur) : 0;
        updateWaveformProgress(waveform, pct);
      };

      audio.addEventListener("loadedmetadata", syncUI);
      audio.addEventListener("loadeddata", syncUI);
      audio.addEventListener("durationchange", syncUI);
      audio.addEventListener("canplay", syncUI);
      audio.addEventListener("timeupdate", syncUI);
      updateWaveformProgress(waveform, 0);
      audio.addEventListener("ended", () => {
        audioCard.classList.remove("is-playing");
        updateWaveformProgress(waveform, 0);
        syncUI();
      });
      audio.addEventListener("play", () => audioCard.classList.add("is-playing"));
      audio.addEventListener("pause", () => audioCard.classList.remove("is-playing"));

      playBtn.addEventListener("click", (e) => {
        e.preventDefault();
        if (audio.paused) {
          if (window._novynAudio && window._novynAudio !== audio) {
            window._novynAudio.pause();
          }
          window._novynAudio = audio;
          const playPromise = audio.play();
          if (playPromise && typeof playPromise.catch === "function") {
            playPromise.catch(() => {
              syncUI();
              showToast("Unable to play this voice note.", "error");
            });
          }
        } else {
          audio.pause();
        }
      });

      waveform.addEventListener("pointerdown", (e) => {
        const dur = getAudioDuration(audio);
        if (!Number.isFinite(dur) || dur <= 0) return;
        const rect = waveform.getBoundingClientRect();
        const pct = (e.clientX - rect.left) / rect.width;
        audio.currentTime = Math.max(0, Math.min(dur, pct * dur));
        syncUI();
      });

      audioCard.append(playBtn, waveform, time, audio);
      body.appendChild(audioCard);
      try { audio.load(); } catch (_) {}
      body.dataset.rawText = attachment?.name || attachmentUrl || message.text || "";
    } else if (attachment) {
      const fileBubble = document.createElement("div");
      fileBubble.className = "file-bubble";

      const fileIcon = document.createElement("div");
      fileIcon.className = "file-icon";
      fileIcon.textContent = "FILE";

      const fileMeta = document.createElement("div");
      fileMeta.className = "file-meta";

      const fileName = document.createElement("div");
      fileName.className = "file-name";
      fileName.textContent = attachment.name || "Attachment";

      const fileSize = document.createElement("div");
      fileSize.className = "file-size";
      const sizeLabel = formatFileSize(attachment.size);
      const typeLabel = attachment.mime || "File";
      fileSize.textContent = sizeLabel ? `${typeLabel} - ${sizeLabel}` : typeLabel;

      const fileUrl = attachmentUrl || trimmedText;
      const downloadUrl = buildAttachmentDownloadUrl(fileUrl, attachment.name || "file");

      const fileDownload = document.createElement("a");
      fileDownload.className = "file-download-link";
      fileDownload.href = downloadUrl;
      fileDownload.textContent = "Download";
      if (attachment.name) {
        fileDownload.setAttribute("download", attachment.name);
      }
      fileDownload.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        triggerAttachmentDownload(downloadUrl, attachment.name || "file");
      });

      fileMeta.append(fileName, fileSize, fileDownload);
      fileBubble.append(fileIcon, fileMeta);
      fileBubble.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        fileViewer.open({
          src: fileUrl,
          fileName: attachment.name || "Attachment",
          mime: attachment.mime || "",
          size: attachment.size || 0,
        });
      });
      body.appendChild(fileBubble);
      body.dataset.rawText = attachment.name || attachmentUrl || message.text || "";
    } else {
      appendMessageTextWithLinks(body, message.text);
      body.dataset.rawText = message.text;
    }
  }

  row.append(body);

  if (!isDeleted && message.id) {
    const replyCount = countRepliesForMessage(message.id);
    if (replyCount > 0) {
      const threadBtn = document.createElement("button");
      threadBtn.type = "button";
      threadBtn.className = "message-thread-pill";
      threadBtn.textContent = `${replyCount} repl${replyCount === 1 ? "y" : "ies"}`;
      threadBtn.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        openThreadForMessage(message.id);
      });
      row.append(threadBtn);
    }
  }

  if (mine && message.failed && message.clientTempId) {
    const retryBtn = document.createElement("button");
    retryBtn.type = "button";
    retryBtn.className = "message-retry-btn";
    retryBtn.textContent = "Retry";
    retryBtn.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      retryFailedMessage(message.clientTempId);
    });
    row.append(retryBtn);
  }

  return row;
}

function appendMessage(message, skipAnimation = false, withSeparator = true, skipSearch = false) {
  const emptyNode = messagesEl.querySelector(".messages-empty");
  if (emptyNode) emptyNode.remove();
  const preserveTop = messagesEl.scrollTop;
  const shouldAutoScroll = shouldAutoScrollForMessage(message, skipAnimation);

  if (withSeparator) {
    appendDateSeparator(message.timestamp);
  }

  const row = buildMessageElement(message, skipAnimation);

  messagesEl.appendChild(row);
  if (!skipSearch) applyMessageSearch();
  if (shouldAutoScroll) {
    const mine = normalizeName(message.from) === normalizeName(me);
    scrollToBottom(skipAnimation || mine);
    scrollState.pinnedToBottom = true;
  } else {
    messagesEl.scrollTop = preserveTop;
  }

  syncProfilePanelStats();
  syncCallLogPanel();
}

function ensureLoadOlderButton() {
  if (!messagesEl) return null;
  if (!loadOlderBtn) {
    loadOlderBtn = document.createElement("button");
    loadOlderBtn.type = "button";
    loadOlderBtn.className = "messages-load-older hidden";
    loadOlderBtn.innerHTML = `
      <span class="load-older-line" aria-hidden="true"></span>
      <span class="load-older-content">
        <span class="load-older-icon" aria-hidden="true">
          <svg viewBox="0 0 22 22" fill="none" focusable="false">
            <g class="load-older-ring-outer">
              <circle
                cx="11"
                cy="11"
                r="9"
                stroke="var(--mint-2)"
                stroke-width="1.5"
                stroke-dasharray="9 24"
                stroke-linecap="round"
              ></circle>
            </g>
            <g class="load-older-ring-inner">
              <circle
                cx="11"
                cy="11"
                r="5"
                stroke="var(--mint-2)"
                stroke-width="1.2"
                stroke-dasharray="5 17"
                stroke-linecap="round"
                opacity="0.45"
              ></circle>
            </g>
            <g class="load-older-dot">
              <circle cx="11" cy="11" r="2.2" fill="var(--mint-2)"></circle>
            </g>
          </svg>
        </span>
        <span class="load-older-text">Load older messages</span>
      </span>
      <span class="load-older-line" aria-hidden="true"></span>
    `;
    loadOlderBtn.setAttribute("aria-label", "Load older messages");
    loadOlderBtn.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      loadOlderMessages();
    });
  }
  if (!loadOlderBtn.parentNode) {
    messagesEl.prepend(loadOlderBtn);
  }
  return loadOlderBtn;
}

function setLoadOlderButtonText(text, btn = loadOlderBtn) {
  if (!btn) return;
  const labelEl = btn.querySelector(".load-older-text");
  if (labelEl) {
    labelEl.textContent = text;
  } else {
    btn.textContent = text;
  }
}

function updateLoadOlderButton() {
  const btn = ensureLoadOlderButton();
  if (!btn) return;
  const remaining = Math.max(0, Number(messageWindowStart) || 0);
  if (remaining <= 0) {
    btn.classList.add("hidden");
    btn.classList.remove("is-loading");
    btn.disabled = false;
    btn.removeAttribute("aria-busy");
    btn.removeAttribute("title");
    btn.setAttribute("aria-label", "Load older messages");
    btn.dataset.remaining = "0";
    setLoadOlderButtonText("Load older messages", btn);
    return;
  }
  const remainingLabel = remaining === 1 ? "1 older message left" : `${remaining} older messages left`;
  setLoadOlderButtonText("Load older messages", btn);
  btn.title = remainingLabel;
  btn.setAttribute("aria-label", `Load older messages. ${remainingLabel}.`);
  btn.classList.remove("is-loading");
  btn.disabled = false;
  btn.removeAttribute("aria-busy");
  btn.dataset.remaining = String(remaining);
  syncLoadOlderButtonVisibility(btn);
}

function syncLoadOlderButtonVisibility(btn = loadOlderBtn) {
  if (!btn) return;
  const remaining = Math.max(0, Number(btn.dataset.remaining) || 0);
  if (remaining <= 0) {
    btn.classList.add("hidden");
    return;
  }
  btn.classList.toggle("hidden", !isNearTop());
}

function setMessageWindowToLatest() {
  messageWindowEnd = conversationMessages.length;
  messageWindowStart = Math.max(0, messageWindowEnd - MAX_VISIBLE_MESSAGES);
}

function getCurrentMessageWindowSize() {
  const rawSize = Number(messageWindowEnd) - Number(messageWindowStart);
  if (!Number.isFinite(rawSize) || rawSize <= 0) return MAX_VISIBLE_MESSAGES;
  return Math.max(MAX_VISIBLE_MESSAGES, Math.floor(rawSize));
}

function captureMessageViewportAnchor() {
  if (!messagesEl) return null;
  const rows = Array.from(messagesEl.querySelectorAll("article.message"));
  if (!rows.length) return null;
  const scrollTop = messagesEl.scrollTop;
  let anchorRow = null;
  for (const row of rows) {
    if (!row) continue;
    if ((row.offsetTop + row.offsetHeight) >= scrollTop) {
      anchorRow = row;
      break;
    }
  }
  if (!anchorRow) anchorRow = rows[0];
  if (!anchorRow) return null;
  const messageId = String(anchorRow.dataset.messageId || "").trim();
  const tempId = String(anchorRow.dataset.clientTempId || "").trim();
  if (!messageId && !tempId) return null;
  return {
    messageId,
    tempId,
    offset: anchorRow.offsetTop - scrollTop,
  };
}

function restoreMessageViewportAnchor(anchor) {
  if (!messagesEl || !anchor) return false;
  const rows = Array.from(messagesEl.querySelectorAll("article.message"));
  if (!rows.length) return false;
  let anchorRow = null;
  if (anchor.messageId) {
    anchorRow = rows.find((row) => row.dataset.messageId === anchor.messageId) || null;
  }
  if (!anchorRow && anchor.tempId) {
    anchorRow = rows.find((row) => row.dataset.clientTempId === anchor.tempId) || null;
  }
  if (!anchorRow) return false;
  const offset = Number(anchor.offset);
  const safeOffset = Number.isFinite(offset) ? offset : 0;
  messagesEl.scrollTop = Math.max(0, anchorRow.offsetTop - safeOffset);
  return true;
}

function renderMessageWindow(options = {}) {
  if (!messagesEl) return;
  const maxVisible = Number.isFinite(Number(options.maxVisible)) && Number(options.maxVisible) > 0
    ? Math.floor(Number(options.maxVisible))
    : MAX_VISIBLE_MESSAGES;
  const preserveScroll = Boolean(options.preserveScroll);
  const prevScrollTop = preserveScroll ? messagesEl.scrollTop : 0;
  const prevScrollHeight = preserveScroll ? messagesEl.scrollHeight : 0;
  const anchor = preserveScroll ? captureMessageViewportAnchor() : null;
  if (preserveScroll) beginMessageViewportMutation();
  try {
    clearMessages();
    ensureLoadOlderButton();

    if (!Number.isFinite(messageWindowEnd) || messageWindowEnd <= 0) {
      messageWindowEnd = conversationMessages.length;
    }
    messageWindowEnd = Math.min(conversationMessages.length, messageWindowEnd);
    if (messageWindowEnd - messageWindowStart > maxVisible) {
      messageWindowStart = Math.max(0, messageWindowEnd - maxVisible);
    }

    let hadRenderError = false;
    for (let i = messageWindowStart; i < messageWindowEnd; i += 1) {
      const msg = conversationMessages[i];
      if (!msg || typeof msg !== "object") continue;
      try {
        if (options.withSeparator !== false) appendDateSeparator(msg.timestamp);
        const row = buildMessageElement(msg, true);
        messagesEl.appendChild(row);
      } catch (err) {
        hadRenderError = true;
        console.warn("Failed to render message row:", err);
      }
    }
    if (hadRenderError && !historyRenderWarningShown) {
      historyRenderWarningShown = true;
      showToast("Some older messages could not be rendered.", "info");
    }

    updateLoadOlderButton();
    if (!options.skipSearch) applyMessageSearch();
    if (preserveScroll) {
      const restoredWithAnchor = restoreMessageViewportAnchor(anchor);
      if (!restoredWithAnchor) {
        const nextHeight = messagesEl.scrollHeight;
        const delta = nextHeight - prevScrollHeight;
        messagesEl.scrollTop = Math.max(0, prevScrollTop + delta);
      }
      scrollState.pinnedToBottom = false;
    }
    syncLoadOlderButtonVisibility();
  } finally {
    if (preserveScroll) {
      let released = false;
      const releaseViewportMutation = () => {
        if (released) return;
        released = true;
        endMessageViewportMutation();
        syncLoadOlderButtonVisibility();
      };
      requestAnimationFrame(releaseViewportMutation);
      setTimeout(releaseViewportMutation, 90);
    }
  }
}

function loadOlderMessages() {
  if (loadOlderInProgress || messageWindowStart <= 0 || !messagesEl) return;
  loadOlderInProgress = true;
  try {
    const btn = ensureLoadOlderButton();
    if (btn) {
      btn.disabled = true;
      btn.classList.add("is-loading");
      btn.setAttribute("aria-busy", "true");
      setLoadOlderButtonText("Loading older messages...", btn);
    }
    scrollState.pinnedToBottom = false;
    const expandedWindowSize = getCurrentMessageWindowSize() + MESSAGE_WINDOW_PAGE;
    messageWindowEnd = conversationMessages.length;
    messageWindowStart = Math.max(0, messageWindowEnd - expandedWindowSize);
    renderMessageWindow({ preserveScroll: true, maxVisible: expandedWindowSize });
  } finally {
    requestAnimationFrame(() => {
      loadOlderInProgress = false;
    });
  }
}

function hasNewerMessages() {
  return messageWindowEnd < conversationMessages.length;
}

function showLatestMessages() {
  setMessageWindowToLatest();
  renderMessageWindow();
  scrollToBottom(true);
  scrollState.pinnedToBottom = true;
  syncLoadOlderButtonVisibility();
}

function updateStats() {
  if (requestCount) {
    requestCount.textContent = String(requests.length);
    requestCount.classList.toggle("has-pending", requests.length > 0);
  }
  if (friendCount)  friendCount.textContent  = String(friends.length);
  if (onlineCount) {
    const online = friends.filter((friend) => (
      normalizeChatKind(friend?.kind || "friend") === "friend"
      && resolveFriendPresenceMode(friend) !== "offline"
    )).length;
    onlineCount.textContent = `${online} online`;
  }
  syncMessageFilterUi();
}

function syncAttachButtonState() {
  const composerDisabled = Boolean(messageInput?.disabled);
  const disabled = composerDisabled || !activeFriend || attachmentUploadState.active;
  if (attachFileBtn) {
    attachFileBtn.disabled = disabled;
    attachFileBtn.classList.toggle("uploading", attachmentUploadState.active);
    attachFileBtn.setAttribute("aria-busy", attachmentUploadState.active ? "true" : "false");
  }
  if (cameraBtn) {
    cameraBtn.disabled = disabled;
    cameraBtn.classList.toggle("uploading", attachmentUploadState.active);
    cameraBtn.setAttribute("aria-busy", attachmentUploadState.active ? "true" : "false");
  }
}

function setComposerEnabled(isEnabled) {
  messageInput.disabled = !isEnabled;
  if (sendButton) sendButton.disabled = !isEnabled;
  if (scheduleBtn) scheduleBtn.disabled = !isEnabled;
  if (voiceBtn) {
    voiceBtn.disabled = !isEnabled;
    if (!isEnabled) resetVoiceState();
  }

  if (!isEnabled) {
    closeScheduleMenu();
    cameraCaptureModal.close();
    stopLocalTyping();
    hideTypingIndicator();
  }

  syncAttachButtonState();
  messageInput.placeholder = "Message";
}

function scrollToUnreadStart() {
  if (!messagesEl) return false;
  if (getSearchQuery()) return false;
  if (!pendingUnreadJump.count) return false;
  if (!activeFriend || normalizeName(activeFriend) !== pendingUnreadJump.friendKey) return false;

  const incoming = Array.from(messagesEl.querySelectorAll("article.message.them"));
  if (!incoming.length) {
    pendingUnreadJump = { friendKey: "", count: 0 };
    return false;
  }

  const index = Math.max(0, incoming.length - pendingUnreadJump.count);
  const target = incoming[index] || incoming[0];
  if (!target) {
    pendingUnreadJump = { friendKey: "", count: 0 };
    return false;
  }

  target.scrollIntoView({ behavior: "auto", block: "start" });
  target.classList.add("highlight-flash");
  setTimeout(() => target.classList.remove("highlight-flash"), 1200);
  scrollState.pinnedToBottom = false;
  pendingUnreadJump = { friendKey: "", count: 0 };
  return true;
}

function renderMessages(messages) {
  conversationMessages = Array.isArray(messages)
    ? messages
      .filter((message) => message && typeof message === "object")
      .map((message) => sanitizeMessagePayload(message) || message)
    : [];
  conversationMessages = appendRestoredPendingMessages(
    conversationMessages,
    activeFriend,
    activeChatKind
  );

  if (!conversationMessages.length) {
    renderMessagesEmptyState("No messages yet. Say hello!");
    applyMessageSearch();
    syncPinnedMessageBar();
    syncProfilePanelStats();
    syncInfoMediaGrid();
    syncCallLogPanel();
    syncActiveConversationAccess();
    return;
  }

  setMessageWindowToLatest();
  renderMessageWindow({ skipSearch: true });

  // Jump to first unread message when available, otherwise bottom
  const jumpedToUnread = scrollToUnreadStart();
  if (!jumpedToUnread) {
    scrollToBottom(true);
    scrollState.pinnedToBottom = true;
  }
  syncLoadOlderButtonVisibility();
  if (window._novynFAB) window._novynFAB.reset();
  applyMessageSearch();
  syncPinnedMessageBar();
  syncProfilePanelStats();
  syncInfoMediaGrid();
  syncCallLogPanel();
  syncActiveConversationAccess();
}

function markConversationMessageDeleted(messageId, deletedAt, replacementText = DELETED_MESSAGE_TEXT) {
  for (const message of conversationMessages) {
    if (message.id !== messageId) continue;
    message.deletedAt = deletedAt || message.deletedAt || new Date().toISOString();
    message.text = replacementText;
    message.editedAt = null;
    message.attachment = null;
    message.pinnedAt = null;
    message.pinnedBy = "";
    message.reactions = {};
    break;
  }
}

function applyDeletedMessageToDom(messageId, replacementText = DELETED_MESSAGE_TEXT) {
  const row = messagesEl.querySelector(`[data-message-id="${messageId}"]`);
  if (!row) return;

  row.classList.add("message-deleted");
  row.classList.remove("message-pinned");
  row.dataset.messageText = replacementText;
  row.dataset.searchText = `${row.dataset.messageFrom || ""} ${replacementText}`;
  delete row.dataset.pinnedAt;
  delete row.dataset.editedAt;
  delete row.dataset.hasAttachment;
  delete row.dataset.messageReactions;

  const body = row.querySelector(".message-body");
  if (body) {
    body.textContent = replacementText;
    body.classList.add("message-body-deleted");
    body.dataset.rawText = replacementText;
  }

  const replyQuote = row.querySelector(".reply-quote");
  if (replyQuote) replyQuote.remove();
  const editedFlag = row.querySelector(".message-edited-flag");
  if (editedFlag) editedFlag.remove();
  const pinnedFlag = row.querySelector(".message-pinned-flag");
  if (pinnedFlag) pinnedFlag.remove();

  const actions = row.querySelector(".msg-actions");
  if (actions) actions.remove();

  const reactions = row.querySelector(".message-reactions");
  if (reactions) reactions.innerHTML = "";
}

function rerenderConversationMessageRow(messageId) {
  if (!messagesEl || !messageId) return;
  const message = getConversationMessageById(messageId);
  if (!message) return;
  const row = messagesEl.querySelector(`[data-message-id="${messageId}"]`);
  if (!row) return;
  const replacement = buildMessageElement(message, true);
  row.replaceWith(replacement);
}

function applyConversationMessageEdit(messageId, text, editedAt) {
  if (!messageId) return false;
  const message = getConversationMessageById(messageId);
  if (!message || message.deletedAt) return false;
  message.text = normalizeMojibakeText(text || message.text || "").trim();
  message.editedAt = editedAt || new Date().toISOString();
  return true;
}

function applyConversationMessagePin(messageId, pinned, pinnedAt, pinnedBy) {
  if (!messageId) return false;
  const message = getConversationMessageById(messageId);
  if (!message || message.deletedAt) return false;
  if (pinned) {
    message.pinnedAt = String(pinnedAt || message.pinnedAt || new Date().toISOString());
    message.pinnedBy = String(pinnedBy || "");
  } else {
    message.pinnedAt = null;
    message.pinnedBy = "";
  }
  return true;
}

function normalizeConversationReactionsPayload(rawReactions) {
  const input = rawReactions && typeof rawReactions === "object" ? rawReactions : {};
  const normalized = {};
  Object.entries(input).forEach(([emoji, rawEntry]) => {
    if (!rawEntry || typeof rawEntry !== "object") return;
    const baseCount = Number(rawEntry.count);
    const userKeys = Array.isArray(rawEntry.userKeys)
      ? rawEntry.userKeys.map((userKey) => normalizeName(userKey)).filter(Boolean)
      : [];
    const users = Array.isArray(rawEntry.users)
      ? rawEntry.users.map((name) => String(name || "").trim()).filter(Boolean)
      : [];
    const count = Number.isFinite(baseCount) && baseCount > 0
      ? Math.floor(baseCount)
      : Math.max(userKeys.length, users.length);
    if (!count) return;
    normalized[emoji] = {
      count,
      mine: Boolean(rawEntry.mine),
      userKeys,
      users,
    };
  });
  return normalized;
}

function applyConversationReactionsUpdate(messageId, reactions) {
  if (!messageId) return;
  const message = getConversationMessageById(messageId);
  if (message) {
    message.reactions = normalizeConversationReactionsPayload(reactions);
  }
  const row = messagesEl ? messagesEl.querySelector(`[data-message-id="${messageId}"]`) : null;
  if (row) {
    const reactionPayload = message?.reactions || normalizeConversationReactionsPayload(reactions);
    if (reactionPayload && Object.keys(reactionPayload).length) {
      try {
        row.dataset.messageReactions = JSON.stringify(reactionPayload);
      } catch (_) {
        delete row.dataset.messageReactions;
      }
    } else {
      delete row.dataset.messageReactions;
    }
  }
}

function requestDiscoverOnline() {
  if (!socket || !socket.emit) return;
  if (!isDashboardPage || !me) return;
  socket.emit("discover_online");
}

function sanitizeDiscoverUser(rawUser) {
  if (!rawUser || typeof rawUser !== "object") return null;
  const username = normalizeMojibakeText(rawUser.username);
  if (!username) return null;
  const online = Boolean(rawUser.online);
  const presence = normalizePresenceMode(rawUser.presence, online ? "online" : "offline");
  return {
    ...rawUser,
    username,
    displayName: normalizeMojibakeText(rawUser.displayName),
    avatarId: normalizeMojibakeText(rawUser.avatarId),
    bio: normalizeMojibakeText(rawUser.bio),
    presence,
    online: presence !== "offline",
  };
}

function setDiscoverUsers(list) {
  discoverUsers = Array.isArray(list)
    ? list.map((entry) => sanitizeDiscoverUser(entry)).filter(Boolean)
    : [];
  renderDiscover();
}

function renderDiscover() {
  if (!discoverPanel || !discoverList) return;
  discoverList.innerHTML = "";
  const meKey = normalizeName(me);
  const friendKeys = new Set(friends.map((friend) => normalizeName(friend.username)));
  const requestKeys = new Set(requests.map((name) => normalizeName(name)));
  const query = friendSearchQuery;
  const filtered = discoverUsers.filter((user) => {
    const username = String(user?.username || "").trim();
    if (!username) return false;
    const key = normalizeName(username);
    if (!key || key === meKey) return false;
    if (friendKeys.has(key) || requestKeys.has(key)) return false;
    if (normalizePresenceMode(user?.presence, user?.online ? "online" : "offline") === "offline") return false;
    if (query) {
      const searchBlob = normalizeSearchText(`${user?.displayName || ""} ${username} ${user?.bio || ""}`);
      if (!searchBlob.includes(query)) return false;
    }
    return true;
  });
  if (discoverEmpty) {
    discoverEmpty.style.display = filtered.length ? "none" : "";
  }
  if (!filtered.length) return;

  filtered.forEach((user) => {
    const item = document.createElement("div");
    item.className = "discover-item";

    const avatar = document.createElement("div");
    avatar.className = "discover-avatar";
    const fallback = String(user?.username || "").slice(0, 2).toUpperCase();
    if (user?.avatarId && window._novynAvatarUtils) {
      window._novynAvatarUtils.applyAvatarToEl(avatar, user.avatarId, fallback || "?");
    } else {
      avatar.textContent = fallback || "?";
    }

    const meta = document.createElement("div");
    meta.className = "discover-meta";
    const name = document.createElement("div");
    name.className = "discover-name";
    const displayName = cleanDisplayName(user?.displayName);
    name.textContent = displayName || user?.username || "User";
    const sub = document.createElement("div");
    sub.className = "discover-sub";
    const bio = cleanDisplayName(user?.bio);
    const presenceLabel = getPresenceLabel(user?.presence);
    const presenceText = presenceLabel === "Online" ? "Online now" : presenceLabel;
    sub.textContent = bio ? `${presenceText} - ${bio}` : presenceText;
    meta.append(name, sub);

    const action = document.createElement("button");
    action.className = "discover-action";
    action.type = "button";
    action.textContent = "Add";
    action.addEventListener("click", () => {
      if (action.disabled) return;
      action.disabled = true;
      action.classList.add("is-disabled");
      action.textContent = "Requested";
      if (user?.username) socket.emit("add_friend", user.username);
    });

    item.append(avatar, meta, action);
    discoverList.appendChild(item);
  });
}


// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Requests Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

function renderRequests() {
  if (!requestList) return;
  requestList.innerHTML = "";
  updateStats();
  updateRequestsBadge();

  const query = friendSearchQuery;
  const filteredRequests = query
    ? requests.filter((name) => normalizeSearchText(name).includes(query))
    : requests;

  if (!filteredRequests.length) {
    const empty       = document.createElement("li");
    empty.className   = "item-card list-empty";
    empty.textContent = requests.length
      ? `No requests match "${friendSearchQuery}"`
      : "No pending requests";
    requestList.appendChild(empty);
    return;
  }

  for (const username of filteredRequests) {
    const li      = document.createElement("li");
    li.className  = "request-card";

    const name        = document.createElement("span");
    name.className    = "request-name";
    name.textContent  = username;

    const btn       = document.createElement("button");
    btn.type        = "button";
    btn.className   = "req-btn accept";
    btn.textContent = "Accept";
    btn.addEventListener("click", () => socket.emit("accept_friend", username));

    li.append(name, btn);
    requestList.appendChild(li);
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Friends Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

function getMyStatusStorageKey() {
  const ownerKey = normalizeName(me || "");
  if (!ownerKey) return "";
  return `${MY_STATUS_STORAGE_PREFIX}:${ownerKey}`;
}

function readMyStatusEntry() {
  const storageKey = getMyStatusStorageKey();
  if (!storageKey) return null;
  try {
    const raw = localStorage.getItem(storageKey);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    const text = String(parsed?.text || "").trim();
    const createdAt = String(parsed?.createdAt || "").trim();
    if (!text || !createdAt) return null;
    const stamp = Date.parse(createdAt);
    if (!Number.isFinite(stamp) || (Date.now() - stamp) > STATUS_EXPIRY_MS) {
      localStorage.removeItem(storageKey);
      return null;
    }
    return { text, createdAt };
  } catch (_) {
    return null;
  }
}

function writeMyStatusEntry(text) {
  const storageKey = getMyStatusStorageKey();
  if (!storageKey) return false;
  const content = String(text || "").trim().slice(0, 280);
  if (!content) return false;
  try {
    localStorage.setItem(storageKey, JSON.stringify({
      text: content,
      createdAt: new Date().toISOString(),
    }));
    return true;
  } catch (_) {
    return false;
  }
}

function removeMyStatusEntry() {
  const storageKey = getMyStatusStorageKey();
  if (!storageKey) return;
  try {
    localStorage.removeItem(storageKey);
  } catch (_) {
    // Ignore storage write issues.
  }
}

function formatStatusTimestamp(iso) {
  if (!iso) return "Just now";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "Just now";
  const now = new Date();
  const timeText = date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  if (date.toDateString() === now.toDateString()) {
    return `Today, ${timeText}`;
  }
  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  if (date.toDateString() === yesterday.toDateString()) {
    return `Yesterday, ${timeText}`;
  }
  const dateText = date.toLocaleDateString([], { month: "short", day: "numeric" });
  return `${dateText}, ${timeText}`;
}

function isRecentStatusTimestamp(iso) {
  const stamp = Date.parse(String(iso || ""));
  if (!Number.isFinite(stamp)) return false;
  return (Date.now() - stamp) <= STATUS_EXPIRY_MS;
}

function getFriendStatusText(friend) {
  const bio = cleanDisplayName(friend?.bio);
  if (bio) return bio;
  const safeLastMessage = normalizeMojibakeText(friend?.lastMessage || "").trim();
  if (safeLastMessage) {
    const fromMe = normalizeName(friend?.lastFrom) === normalizeName(me);
    const callPreview = formatCallLogPreview(safeLastMessage, fromMe);
    const value = (callPreview || safeLastMessage).trim();
    if (value) return value.slice(0, 220);
  }
  return friend?.online ? "Online now" : getFriendPresenceText(friend);
}

function friendHasFreshStatus(friend) {
  if (!friend) return false;
  if (cleanDisplayName(friend?.bio)) return true;
  if (friend?.online) return true;
  if (String(friend?.lastMessage || "").trim()) {
    if (!friend?.lastTimestamp) return true;
    return isRecentStatusTimestamp(friend.lastTimestamp);
  }
  return isRecentStatusTimestamp(friend?.lastSeenAt);
}

function buildFriendStatusEntry(friend) {
  if (!friend) return null;
  const username = String(friend?.username || "").trim();
  if (!username) return null;
  return {
    isMine: false,
    key: normalizeName(username),
    username,
    displayName: getFriendDisplayName(friend),
    avatarId: String(friend?.avatarId || ""),
    text: getFriendStatusText(friend),
    timestamp: String(friend?.lastTimestamp || friend?.lastSeenAt || new Date().toISOString()),
    online: Boolean(friend?.online),
  };
}

function buildMyStatusEntry() {
  const status = readMyStatusEntry();
  if (!status || !status.text || !me) return null;
  return {
    isMine: true,
    key: normalizeName(me),
    username: me,
    displayName: getMyDisplayName(),
    avatarId: String(myProfile?.avatarId || ""),
    text: status.text,
    timestamp: status.createdAt,
    online: true,
  };
}

function getFriendActivityTimestamp(friend) {
  const lastSeenAt = Date.parse(String(friend?.lastSeenAt || ""));
  const lastMessageAt = Date.parse(String(friend?.lastTimestamp || ""));
  const lastSeenValue = Number.isFinite(lastSeenAt) ? lastSeenAt : 0;
  const lastMessageValue = Number.isFinite(lastMessageAt) ? lastMessageAt : 0;
  return Math.max(lastSeenValue, lastMessageValue);
}

function getUpdatesFriends() {
  const query = friendSearchQuery;
  const directFriends = friends.filter((friend) => normalizeChatKind(friend?.kind || "friend") === "friend");
  const visibleFriends = directFriends
    .filter((friend) => !isBlockedFriendEntry(friend))
    .filter((friend) => friendHasFreshStatus(friend));
  const filtered = query
    ? visibleFriends.filter((friend) => getFriendSearchBlob(friend).includes(query))
    : visibleFriends;

  return filtered
    .slice()
    .sort((a, b) => {
      if (Boolean(a?.online) !== Boolean(b?.online)) {
        return a?.online ? -1 : 1;
      }
      const activityDelta = getFriendActivityTimestamp(b) - getFriendActivityTimestamp(a);
      if (activityDelta !== 0) return activityDelta;
      return getFriendDisplayName(a).localeCompare(getFriendDisplayName(b));
    })
    .slice(0, MAX_UPDATES_STRIP_ITEMS);
}

function getStatusPlaybackEntries(options = {}) {
  const includeMine = Boolean(options.includeMine);
  const list = getUpdatesFriends()
    .map((friend) => buildFriendStatusEntry(friend))
    .filter(Boolean);
  if (includeMine) {
    const mine = buildMyStatusEntry();
    if (mine) list.unshift(mine);
  }
  return list;
}

function getStatusViewerCurrentEntry() {
  const index = Number(statusViewerState.index);
  if (!Number.isFinite(index) || index < 0) return null;
  return statusViewerState.entries[index] || null;
}

function setStatusViewerProgress(value = 0) {
  if (!statusViewerProgressBar) return;
  const ratio = Number.isFinite(Number(value)) ? Math.max(0, Math.min(1, Number(value))) : 0;
  statusViewerProgressBar.style.width = `${(ratio * 100).toFixed(2)}%`;
}

function clearStatusViewerTimer() {
  if (statusViewerState.timerId) {
    clearInterval(statusViewerState.timerId);
    statusViewerState.timerId = null;
  }
  statusViewerState.startedAt = 0;
}

function renderStatusViewerEntry() {
  const entry = getStatusViewerCurrentEntry();
  if (!entry || !statusViewerModal) {
    closeStatusViewer();
    return;
  }
  const fallback = String(entry.displayName || entry.username || "?").slice(0, 2).toUpperCase() || "?";
  if (statusViewerAvatar) {
    if (entry.avatarId && window._novynAvatarUtils) {
      window._novynAvatarUtils.applyAvatarToEl(statusViewerAvatar, entry.avatarId, fallback);
    } else {
      statusViewerAvatar.style.background = "";
      statusViewerAvatar.textContent = fallback;
    }
  }
  if (statusViewerName) statusViewerName.textContent = String(entry.displayName || entry.username || "Status");
  if (statusViewerTime) statusViewerTime.textContent = formatStatusTimestamp(entry.timestamp);
  if (statusViewerText) statusViewerText.textContent = String(entry.text || "No status available.");
  if (statusViewerEditBtn) statusViewerEditBtn.classList.toggle("hidden", !entry.isMine);
  if (statusViewerPrevBtn) statusViewerPrevBtn.disabled = statusViewerState.index <= 0;
  if (statusViewerNextBtn) statusViewerNextBtn.disabled = statusViewerState.index >= (statusViewerState.entries.length - 1);

  clearStatusViewerTimer();
  setStatusViewerProgress(0);
  statusViewerState.startedAt = Date.now();
  statusViewerState.timerId = setInterval(() => {
    const elapsed = Date.now() - statusViewerState.startedAt;
    const ratio = elapsed / STATUS_SLIDE_MS;
    setStatusViewerProgress(ratio);
    if (ratio < 1) return;
    stepStatusViewer(1, { auto: true });
  }, 90);
}

function stepStatusViewer(direction, options = {}) {
  if (!statusViewerState.entries.length) {
    closeStatusViewer();
    return;
  }
  const nextIndex = statusViewerState.index + (direction < 0 ? -1 : 1);
  if (nextIndex < 0 || nextIndex >= statusViewerState.entries.length) {
    if (options.auto) {
      closeStatusViewer();
    } else {
      setStatusViewerProgress(1);
    }
    return;
  }
  statusViewerState.index = nextIndex;
  renderStatusViewerEntry();
}

function closeStatusViewer() {
  clearStatusViewerTimer();
  setStatusViewerProgress(0);
  statusViewerState.entries = [];
  statusViewerState.index = -1;
  if (statusViewerModal) statusViewerModal.classList.add("hidden");
  document.body.classList.remove("status-viewer-open");
}

function openStatusViewerByUsername(username, options = {}) {
  const targetKey = normalizeName(username);
  if (!targetKey || !statusViewerModal) return false;
  const entries = getStatusPlaybackEntries({ includeMine: Boolean(options.includeMine) });
  if (!entries.length) {
    showToast("No statuses yet.", "info");
    return false;
  }

  let startIndex = entries.findIndex((entry) => normalizeName(entry.username) === targetKey);
  if (startIndex < 0) startIndex = 0;

  statusViewerState.entries = entries;
  statusViewerState.index = startIndex;
  statusViewerModal.classList.remove("hidden");
  document.body.classList.add("status-viewer-open");
  renderStatusViewerEntry();
  return true;
}

async function promptForMyStatus(options = {}) {
  const existing = readMyStatusEntry();
  const nextValue = await appDialog.openPrompt({
    title: existing ? "Update your status" : "Post a status",
    description: "Statuses disappear after 24 hours.",
    label: "Status text",
    defaultValue: existing?.text || "",
    placeholder: "What's on your mind?",
    confirmText: existing ? "Update" : "Post",
    maxLength: 280,
    multiline: true,
  });
  if (nextValue === null) return false;

  const text = String(nextValue || "").trim();
  if (!text) {
    if (existing) {
      removeMyStatusEntry();
      showToast("Status removed.", "success");
      renderUpdates();
      closeStatusViewer();
    } else {
      showToast("Status not added.", "info");
    }
    return false;
  }

  if (!writeMyStatusEntry(text)) {
    showToast("Couldn't save status.", "error");
    return false;
  }

  showToast(existing ? "Status updated." : "Status posted.", "success");
  renderUpdates();
  if (options.openViewer !== false) {
    openStatusViewerByUsername(me, { includeMine: true });
  }
  return true;
}

function renderUpdates() {
  if (!storyFriendList) return;
  storyFriendList.innerHTML = "";

  const meStoryItem = storiesRow ? storiesRow.querySelector(".story-item") : null;
  const meStatus = buildMyStatusEntry();
  if (meStoryItem) {
    const meRing = meStoryItem.querySelector(".story-ring");
    meStoryItem.dataset.storyAction = "my-status";
    meStoryItem.setAttribute("role", "button");
    meStoryItem.tabIndex = 0;
    meStoryItem.title = meStatus ? `View your status (${formatStatusTimestamp(meStatus.timestamp)})` : "Add a status";
    meStoryItem.setAttribute("aria-label", meStatus ? "View your status" : "Add your status");
    if (meRing) {
      meRing.classList.toggle("add", !meStatus);
      meRing.classList.remove("muted");
    }
  }

  const updates = getUpdatesFriends();
  updates.forEach((friend) => {
    const statusEntry = buildFriendStatusEntry(friend);
    if (!statusEntry) return;
    const displayName = statusEntry.displayName;
    const fallback = displayName.slice(0, 2).toUpperCase() || "?";
    const item = document.createElement("div");
    item.className = "story-item";
    item.dataset.storyAction = "status";
    item.dataset.storyUsername = statusEntry.username;
    item.setAttribute("role", "button");
    item.tabIndex = 0;
    item.title = `${statusEntry.text.slice(0, 70)}${statusEntry.text.length > 70 ? "..." : ""}`;
    item.setAttribute("aria-label", `View ${displayName}'s status`);

    const ring = document.createElement("div");
    ring.className = "story-ring";
    const inner = document.createElement("div");
    inner.className = "story-inner";
    const avatar = document.createElement("div");
    avatar.className = "story-avatar";
    if (statusEntry.avatarId && window._novynAvatarUtils) {
      window._novynAvatarUtils.applyAvatarToEl(avatar, statusEntry.avatarId, fallback);
    } else {
      avatar.textContent = fallback;
    }
    inner.appendChild(avatar);
    ring.appendChild(inner);

    const label = document.createElement("span");
    label.className = "story-label";
    label.textContent = displayName;
    label.title = `${displayName} - ${formatStatusTimestamp(statusEntry.timestamp)}`;

    item.append(ring, label);
    storyFriendList.appendChild(item);
  });
}

function friendPreview(friend) {
  if (!friend.lastMessage) {
    const bio = cleanDisplayName(friend?.bio);
    if (bio) return bio;
    const mode = resolveFriendPresenceMode(friend);
    if (mode === "away") return "Away";
    if (mode === "busy") return "Busy";
    return mode === "online" ? "Online now" : "No messages yet";
  }
  const safeLastMessage = normalizeMojibakeText(friend.lastMessage);
  const fromMe = normalizeName(friend.lastFrom) === normalizeName(me);
  const callPreview = formatCallLogPreview(safeLastMessage, fromMe);
  const previewText = callPreview || safeLastMessage;
  if (fromMe) {
    return `You: ${previewText}`;
  }
  if (friend.lastFrom) {
    return `${getFriendDisplayName(friend)}: ${previewText}`;
  }
  return previewText;
}

function findFriend(username, kind = "") {
  const key = normalizeName(username);
  if (!key) return null;
  const normalizedKind = kind ? normalizeChatKind(kind) : "";
  return friends.find((friend) => {
    if (normalizeName(friend?.username) !== key) return false;
    if (!normalizedKind) return true;
    return normalizeChatKind(friend?.kind || "friend") === normalizedKind;
  }) || null;
}

function setInfoPanelStatus(text, state) {
  if (!infoPanelStatus) return;
  infoPanelStatus.textContent = normalizeMojibakeText(text);
  infoPanelStatus.classList.remove("online", "away", "busy", "offline", "me");
  if (state) infoPanelStatus.classList.add(state);
}

function applyInfoAvatar(avatarEl, avatarId, fallbackText) {
  if (!avatarEl) return;
  const utils = window._novynAvatarUtils;
  if (utils && avatarId) {
    utils.applyAvatarToEl(avatarEl, avatarId, fallbackText);
    return;
  }
  avatarEl.style.background = "";
  avatarEl.textContent = fallbackText || "?";
}

function maybeResetInfoPanelScroll() {
  if (!document.body || !document.body.classList.contains("info-open")) return;
  const nextKey = activeFriend ? `${normalizeChatKind(activeChatKind)}:${normalizeName(activeFriend)}` : "me";
  if (!nextKey || nextKey === lastInfoPanelFriendKey) return;
  const inner = document.querySelector(".info-inner");
  if (inner) inner.scrollTop = 0;
  lastInfoPanelFriendKey = nextKey;
}

function setInfoPanelMode(mode = "contact") {
  const isGroup = mode === "group";
  if (infoPanel) {
    infoPanel.classList.toggle("is-group", isGroup);
    infoPanel.setAttribute("aria-label", isGroup ? "Group info" : "Contact info");
  }
  if (infoToggleBtn) infoToggleBtn.setAttribute("aria-label", isGroup ? "Group details" : "Contact details");
  if (infoPanelTitle) infoPanelTitle.textContent = isGroup ? "Group info" : "Contact info";
  if (infoTagsSection) infoTagsSection.classList.toggle("hidden", isGroup);
  if (groupInfoSection) groupInfoSection.classList.toggle("hidden", !isGroup);
}

function renderGroupMemberList(groupInfo) {
  if (!groupMemberList || !groupMembersMeta) return;
  if (!groupInfo || !Array.isArray(groupInfo.members) || !groupInfo.members.length) {
    groupMembersMeta.textContent = "0";
    groupMemberList.innerHTML = '<div class="group-member-empty">No members yet</div>';
    return;
  }

  const meRole = groupInfo?.me?.role || "member";
  const canManageMembers = meRole === "owner" || meRole === "admin";
  const canManageRoles = meRole === "owner";

  groupMembersMeta.textContent = `${groupInfo.members.length}`;
  groupMemberList.innerHTML = "";

  groupInfo.members.forEach((member) => {
    const item = document.createElement("div");
    item.className = "group-member-item";

    const avatar = document.createElement("div");
    avatar.className = "group-member-avatar";
    const fallback = (member.displayName || member.username || "?").slice(0, 2).toUpperCase();
    if (member.avatarId && window._novynAvatarUtils) {
      window._novynAvatarUtils.applyAvatarToEl(avatar, member.avatarId, fallback);
    } else {
      avatar.textContent = fallback;
    }

    const meta = document.createElement("div");
    meta.className = "group-member-meta";

    const name = document.createElement("div");
    name.className = "group-member-name";
    const display = member.displayName || member.username;
    const isMe = normalizeName(member.username) === normalizeName(me);
    name.textContent = isMe ? `${display} (You)` : display;
    name.title = `@${member.username}`;

    const sub = document.createElement("div");
    sub.className = "group-member-sub";
    const memberPresence = normalizePresenceMode(member?.presence, member?.online ? "online" : "offline");
    if (memberPresence === "away") {
      sub.textContent = "Away";
    } else if (memberPresence === "busy") {
      sub.textContent = "Busy";
    } else if (memberPresence === "online") {
      sub.textContent = "Online";
    } else if (member.lastSeenAt) {
      sub.textContent = formatLastSeen(member.lastSeenAt);
    } else {
      sub.textContent = "Offline";
    }

    const role = document.createElement("span");
    role.className = `group-member-role ${member.role}`;
    role.textContent = member.role === "owner" ? "Owner" : (member.role === "admin" ? "Admin" : "Member");

    meta.append(name, sub);
    item.append(avatar, meta, role);

    const canToggleRole = canManageRoles && !member.isOwner && !isMe;
    const canRemove = canManageMembers
      && !member.isOwner
      && !isMe
      && (meRole === "owner" || !member.isAdmin);

    if (canToggleRole || canRemove) {
      const actions = document.createElement("div");
      actions.className = "group-member-actions";

      if (canToggleRole) {
        const roleBtn = document.createElement("button");
        roleBtn.type = "button";
        roleBtn.className = "group-member-action-btn role";
        roleBtn.textContent = member.isAdmin ? "Make member" : "Make admin";
        roleBtn.addEventListener("click", () => {
          socket.emit("set_group_member_role", {
            groupId: groupInfo.id,
            username: member.username,
            role: member.isAdmin ? "member" : "admin",
          });
        });
        actions.appendChild(roleBtn);
      }

      if (canRemove) {
        const removeBtn = document.createElement("button");
        removeBtn.type = "button";
        removeBtn.className = "group-member-action-btn remove";
        removeBtn.textContent = "Remove";
        removeBtn.addEventListener("click", async () => {
          const confirmed = await appDialog.openConfirm({
            title: `Remove @${member.username}?`,
            description: "This member will lose access to the group until added again.",
            confirmText: "Remove",
            danger: true,
          });
          if (!confirmed) return;
          socket.emit("remove_group_member", {
            groupId: groupInfo.id,
            username: member.username,
          });
        });
        actions.appendChild(removeBtn);
      }

      item.appendChild(actions);
    }

    groupMemberList.appendChild(item);
  });
}

function syncGroupInfoSection() {
  const hasActive = Boolean(activeFriend);
  const activeEntry = getActiveChatEntry();
  const isGroup = normalizeChatKind(activeEntry?.kind || activeChatKind) === "group";
  setInfoPanelMode(isGroup ? "group" : "contact");

  if (!infoAddMembersBtn) {
    if (isGroup) requestGroupInfo(resolveGroupChatId(activeFriend, "group"), { kind: "group" });
    syncClearChatActions({ hasActive, activeEntry, isGroup });
    return;
  }

  infoAddMembersBtn.classList.toggle("hidden", !isGroup);
  infoAddMembersBtn.disabled = !isGroup;

  if (!isGroup) {
    syncClearChatActions({ hasActive, activeEntry, isGroup });
    return;
  }

  const groupId = resolveGroupChatId(activeFriend, "group");
  const groupInfo = getGroupInfo(groupId, "group");
  const meRole = groupInfo?.me?.role || "member";
  const canAdd = meRole === "owner" || meRole === "admin";
  infoAddMembersBtn.disabled = !canAdd;
  infoAddMembersBtn.textContent = "Add members";
  infoAddMembersBtn.title = canAdd ? "Add members to this group" : "Only admins can add members";

  if (!groupInfo) {
    if (!groupId) {
      if (groupMembersMeta) groupMembersMeta.textContent = "0";
      if (groupMemberList) {
        groupMemberList.innerHTML = '<div class="group-member-empty">Unable to load members.</div>';
      }
      syncClearChatActions({ hasActive, activeEntry, isGroup });
      return;
    }
    if (groupMembersMeta) groupMembersMeta.textContent = "...";
    if (groupMemberList) {
      groupMemberList.innerHTML = '<div class="group-member-empty">Loading members...</div>';
    }
    requestGroupInfo(groupId, { kind: "group" });
    syncClearChatActions({ hasActive, activeEntry, isGroup });
    return;
  }
  renderGroupMemberList(groupInfo);
  syncClearChatActions({ hasActive, activeEntry, isGroup });
}

function syncInfoPanel() {
  if (!infoPanelName || !infoPanelAvatar || !infoPanelHandle || !infoPanelStatus) return;

  if (activeFriend) {
    const friend = findFriend(activeFriend, activeChatKind);
    const isGroup = normalizeChatKind(friend?.kind || activeChatKind) === "group";
    if (!friend) {
      infoPanelName.textContent = "Loading...";
      infoPanelHandle.textContent = "";
      setInfoPanelStatus("Offline", "offline");
      syncGroupInfoSection();
      maybeResetInfoPanelScroll();
      return;
    }

    infoPanelName.textContent = getFriendDisplayName(friend);
    infoPanelHandle.textContent = isGroup ? `#${friend.username}` : `@${friend.username}`;
    infoPanelHandle.title = isGroup ? `#${friend.username}` : `@${friend.username}`;
    applyInfoAvatar(
      infoPanelAvatar,
      friend.avatarId,
      getFriendDisplayName(friend).slice(0, 2).toUpperCase()
    );
    if (isGroup) {
      const members = Number(friend.memberCount) || 0;
      const online = Number(friend.onlineCount) || 0;
      const statusText = online > 0
        ? `${online} online - ${members} members`
        : `${members} member${members === 1 ? "" : "s"}`;
      setInfoPanelStatus(statusText, online > 0 ? "online" : "offline");
      infoPanelStatus.title = statusText;
    } else {
      const safety = getFriendSafety(friend.username);
      const presenceMode = resolveFriendPresenceMode(friend);
      const statusText = safety.blockedByMe
        ? "Blocked by you"
        : safety.blockedYou
          ? "Blocked you"
          : presenceMode === "away"
            ? "Away"
            : presenceMode === "busy"
              ? "Busy"
              : presenceMode === "online"
                ? "Online"
            : formatLastSeen(friend.lastSeenAt);
      const statusTone = safety.blocked ? "offline" : presenceMode;
      setInfoPanelStatus(statusText, statusTone);
      infoPanelStatus.title = safety.blocked
        ? (safety.blockedByMe ? "You blocked this user." : "This user blocked you.")
        : statusText;
    }
    syncGroupInfoSection();
    maybeResetInfoPanelScroll();
    return;
  }

  setInfoPanelMode("contact");
  if (groupMemberList && groupMembersMeta) {
    groupMembersMeta.textContent = "0";
    groupMemberList.innerHTML = '<div class="group-member-empty">No members yet</div>';
  }
  if (infoAddMembersBtn) {
    infoAddMembersBtn.classList.add("hidden");
    infoAddMembersBtn.disabled = true;
  }
  const myName = getMyDisplayName();
  infoPanelName.textContent = myName;
  infoPanelHandle.textContent = me ? `@${me}` : "@you";
  infoPanelHandle.title = me ? `@${me}` : "@you";
  applyInfoAvatar(infoPanelAvatar, myProfile.avatarId, (me || "You").slice(0, 2).toUpperCase());
  setInfoPanelStatus("You", "me");
  infoPanelStatus.title = "Your profile";
  maybeResetInfoPanelScroll();
}


function renderActiveFriendPresence() {
  if (document.body) {
    document.body.classList.toggle("friend-selected", Boolean(activeFriend));
  }
  if (!activeFriend) {
    document.body.classList.remove("info-open");
  }
  syncInfoPanel();

  if (!activePresence || !activeFriendAvatar) return;

  if (!activeFriend) {
    activePresence.classList.add("hidden");
    activeFriendAvatar.classList.remove("online");
    activeFriendAvatar.textContent = "?";
    activeFriendAvatar.style.background = "";
    if (activeFriendPresenceLine) {
      activeFriendPresenceLine.textContent = "Select a conversation to start chatting";
      activeFriendPresenceLine.classList.remove("online", "away", "busy", "offline");
    }
    syncProfilePanel();
    return;
  }

  const friend = getActiveChatEntry();
  if (!friend) {
    activePresence.classList.add("hidden");
    if (activeFriendPresenceLine) {
      activeFriendPresenceLine.textContent = "Loading conversation status...";
      activeFriendPresenceLine.classList.remove("online", "away", "busy", "offline");
    }
    syncProfilePanel();
    return;
  }

  const isGroup = normalizeChatKind(friend.kind || activeChatKind) === "group";
  const displayName = getFriendDisplayName(friend);

  activePresence.classList.remove("hidden");
  activeFriendLabel.textContent = displayName;
  activeFriendLabel.title = isGroup ? `#${friend.username}` : `@${friend.username}`;

  const fallback = displayName.slice(0, 2).toUpperCase() || "?";
  if (friend.avatarId && window._novynAvatarUtils) {
    window._novynAvatarUtils.applyAvatarToEl(
      activeFriendAvatar,
      friend.avatarId,
      fallback
    );
  } else {
    activeFriendAvatar.style.background = "";
    activeFriendAvatar.textContent = fallback;
  }

  const presenceMode = isGroup ? "offline" : resolveFriendPresenceMode(friend);
  const showOnlineMarker = isGroup
    ? Number(friend.onlineCount) > 0
    : presenceMode !== "offline";
  activeFriendAvatar.classList.toggle("online", showOnlineMarker);
  activeFriendAvatar.title = isGroup
    ? `${Number(friend.memberCount) || 0} members`
    : `${friend.username} is ${getPresenceLabel(presenceMode).toLowerCase()}`;

  if (activeFriendPresenceLine) {
    if (isGroup) {
      const members = Number(friend.memberCount) || 0;
      const online = Number(friend.onlineCount) || 0;
      const statusText = online > 0
        ? `${online} online - ${members} members`
        : `${members} members`;
      activeFriendPresenceLine.textContent = statusText;
      activeFriendPresenceLine.classList.remove("away", "busy");
      activeFriendPresenceLine.classList.toggle("online", online > 0);
      activeFriendPresenceLine.classList.toggle("offline", online <= 0);
    } else {
      const safety = getFriendSafety(friend.username, "friend");
      const statusText = safety.blockedByMe
        ? "Blocked by you"
        : safety.blockedYou
          ? "Blocked you"
          : presenceMode === "away"
            ? "Away"
            : presenceMode === "busy"
              ? "Busy"
              : presenceMode === "online"
            ? "Online now"
            : formatLastSeen(friend.lastSeenAt);
      activeFriendPresenceLine.textContent = statusText;
      activeFriendPresenceLine.classList.remove("online", "away", "busy", "offline");
      activeFriendPresenceLine.classList.add(safety.blocked ? "offline" : presenceMode);
    }
  }

  syncProfilePanel(friend);
}

function syncRemoveFriendButton() {
  const hasActive = Boolean(activeFriend);
  const activeEntry = hasActive ? getActiveChatEntry() : null;
  const isGroup = normalizeChatKind(activeEntry?.kind || activeChatKind) === "group";
  if (removeFriendBtn) {
    removeFriendBtn.classList.toggle("hidden", !hasActive);
    removeFriendBtn.disabled = !hasActive;
    if (hasActive) {
      if (isGroup) {
        const label = getFriendDisplayName(activeEntry || { username: activeFriend });
        removeFriendBtn.textContent = "Leave";
        removeFriendBtn.title = `Leave ${label}`;
        removeFriendBtn.setAttribute("aria-label", `Leave ${label}`);
      } else {
        removeFriendBtn.textContent = "Remove";
        removeFriendBtn.title = `Unfriend @${activeFriend}`;
        removeFriendBtn.setAttribute("aria-label", `Unfriend ${activeFriend}`);
      }
    } else {
      removeFriendBtn.textContent = "Remove";
      removeFriendBtn.title = "Unfriend";
      removeFriendBtn.setAttribute("aria-label", "Unfriend");
    }
  }
  syncClearChatActions({ hasActive, activeEntry, isGroup });
}

function syncClearChatActions(options = {}) {
  const hasActive = options.hasActive !== undefined ? Boolean(options.hasActive) : Boolean(activeFriend);
  const activeEntry = options.activeEntry !== undefined
    ? options.activeEntry
    : (hasActive ? getActiveChatEntry() : null);
  const isGroup = options.isGroup !== undefined
    ? Boolean(options.isGroup)
    : normalizeChatKind(activeEntry?.kind || activeChatKind) === "group";
  const target = hasActive
    ? (isGroup
      ? resolveGroupChatId(activeEntry?.username || activeFriend, "group")
      : (activeEntry?.username || activeFriend))
    : "";
  const label = hasActive
    ? getFriendDisplayName(activeEntry || { username: activeFriend })
    : "chat";
  const groupId = isGroup ? resolveGroupChatId(activeEntry?.username || activeFriend, "group") : "";
  const groupInfo = isGroup && groupId ? getGroupInfo(groupId, "group") : null;
  const meRole = groupInfo?.me?.role || "member";
  const canClearGroup = !isGroup || meRole === "owner" || meRole === "admin";
  if (isGroup && groupId && !groupInfo) {
    requestGroupInfo(groupId, { kind: "group" });
  }

  if (clearChatBtn) {
    clearChatBtn.classList.toggle("hidden", !hasActive);
    clearChatBtn.disabled = !hasActive || !canClearGroup;
    clearChatBtn.textContent = "Clear chat";
    clearChatBtn.title = !hasActive
      ? "Clear chat history"
      : (!canClearGroup
        ? "Only group admins can clear chat history"
        : (isGroup ? `Clear "${label}" history` : `Clear history with @${target || activeFriend}`));
    clearChatBtn.setAttribute("aria-label", clearChatBtn.title || "Clear chat history");
  }

  if (chatQuickClearItem) {
    chatQuickClearItem.classList.toggle("hidden", !hasActive);
    chatQuickClearItem.disabled = !hasActive || !canClearGroup;
    chatQuickClearItem.textContent = isGroup ? "Clear this group chat" : "Clear this chat";
    chatQuickClearItem.title = !hasActive
      ? "Select a chat first"
      : (!canClearGroup ? "Only group admins can clear group chat" : `Clear messages in ${label}`);
  }
}

async function requestClearActiveChat() {
  if (!activeFriend) {
    showToast("Select a chat first.", "info");
    return;
  }
  const activeEntry = getActiveChatEntry();
  const chatKind = normalizeChatKind(activeEntry?.kind || activeChatKind);
  const target = chatKind === "group"
    ? resolveGroupChatId(activeEntry?.username || activeFriend, "group")
    : (activeEntry?.username || activeFriend);
  if (!target) return;
  if (chatKind === "group") {
    const groupInfo = getGroupInfo(target, "group");
    if (!groupInfo) {
      requestGroupInfo(target, { kind: "group", force: true });
      showToast("Loading group permissions. Try again.", "info");
      return;
    }
    const meRole = groupInfo?.me?.role || "member";
    if (!(meRole === "owner" || meRole === "admin")) {
      showToast("Only group admins can clear group chat.", "error");
      return;
    }
  }

  const label = getFriendDisplayName(activeEntry || { username: activeFriend });
  const title = chatKind === "group"
    ? `Clear "${label}" chat history?`
    : `Clear chat with @${target}?`;
  const description = chatKind === "group"
    ? "This removes all messages in this group chat for everyone."
    : `This removes all messages in your chat with @${target}.`;
  const confirmed = await appDialog.openConfirm({
    title,
    description,
    confirmText: "Clear chat",
    danger: true,
  });
  if (!confirmed) return;
  socket.emit("clear_chat", { to: target, toType: chatKind });
}

function clearActiveFriendSelection() {
  persistActiveMessageDraft();
  if (activeFriend) stopLocalTyping(activeFriend);
  if (activeFriend) {
    updateLabsLastViewedForChat(getLabsChatKey(activeFriend, activeChatKind));
  }
  closeScheduleMenu();
  setScheduledPanelExpanded(false);
  activeFriend = "";
  activeChatKind = "friend";
  pendingUnreadJump = { friendKey: "", count: 0 };
  setActiveChatTarget("");
  conversationMessages = [];
  clearReply();
  resetMessageSearch();
  if (activeFriendLabel) {
    activeFriendLabel.textContent = "Select a conversation";
    activeFriendLabel.title = "";
  }
  if (activeFriendPresenceLine) {
    activeFriendPresenceLine.textContent = "Choose a chat to start messaging";
    activeFriendPresenceLine.classList.remove("online", "away", "busy", "offline");
  }
  renderActiveFriendPresence();
  syncRemoveFriendButton();
  syncSafetyActionButtons();
  setComposerEnabled(false);
  if (messageInput) {
    messageInput.value = "";
  }
  if (sendButton) {
    sendButton.classList.remove("ready");
  }
  renderMessagesEmptyState(EMPTY_CONVERSATION_HINT);
  applyLabsMoodForActiveChat();
  syncInfoMediaGrid();
  renderScheduledPanel();
  renderFriends();
}

function setActiveFriend(username, kind = "friend") {
  persistActiveMessageDraft();
  closeScheduleMenu();
  setScheduledPanelExpanded(false);
  const nextKind = normalizeChatKind(kind);
  if (
    activeFriend
    && (normalizeName(activeFriend) !== normalizeName(username) || normalizeChatKind(activeChatKind) !== nextKind)
  ) {
    updateLabsLastViewedForChat(getLabsChatKey(activeFriend, activeChatKind));
  }
  if (
    activeFriend &&
    (normalizeName(activeFriend) !== normalizeName(username) || normalizeChatKind(activeChatKind) !== nextKind)
  ) {
    stopLocalTyping(activeFriend);
  }

  if (!username) {
    clearActiveFriendSelection();
    return;
  }

  if (username) {
    const friend = findFriend(username, nextKind);
    pendingUnreadJump = {
      friendKey: normalizeName(username),
      count: Number(friend?.unreadCount) || 0,
    };
  } else {
    pendingUnreadJump = { friendKey: "", count: 0 };
  }

  activeFriend = username;
  activeChatKind = nextKind;
  setActiveChatTarget(username, nextKind);
  conversationMessages = [];
  clearReply();
  resetMessageSearch();
  activeFriendLabel.textContent = "Loading...";
  renderActiveFriendPresence();
  syncRemoveFriendButton();
  setComposerEnabled(true);
  syncActiveConversationAccess();
  applyActiveMessageDraft();
  renderMessagesEmptyState("Loading conversation...");
  socket.emit("get_history", { to: username, toType: nextKind });
  if (nextKind === "group") requestGroupInfo(resolveGroupChatId(username, "group"), { kind: "group", force: true });
  requestScheduledMessagesForActiveChat();
  renderFriends();
  applyLabsMoodForActiveChat();

  // Focus input after selecting friend (better UX, especially on desktop)
  if (messageInput) {
    setTimeout(() => messageInput.focus(), 50);
  }
}

function renderFriends() {
  renderUpdates();
  if (!friendList) return;
  friendList.innerHTML = "";
  updateStats();

  const isContactsView = sidebarView === "contacts";
  const isMessagesView = sidebarView === "messages";
  const query = friendSearchQuery;
  const baseFriends = friends.filter((friend) => {
    const chatKind = normalizeChatKind(friend?.kind || "friend");
    const isGroup = chatKind === "group";
    if (isContactsView && isGroup) return false;
    if (!isMessagesView) return true;
    if (messageListFilter === "groups") return isGroup;
    if (messageListFilter === "blocked") return isBlockedFriendEntry(friend);
    if (messageListFilter === "unread") return (Number(friend?.unreadCount) || 0) > 0;
    return true;
  });
  const filteredFriends = query
    ? baseFriends.filter((friend) => getFriendSearchBlob(friend).includes(query))
    : baseFriends;
  const sortedFriends = filteredFriends.slice().sort((a, b) => {
    if (sidebarView === "contacts") {
      return getFriendDisplayName(a).localeCompare(getFriendDisplayName(b));
    }
    const aTs = a.lastTimestamp || "";
    const bTs = b.lastTimestamp || "";
    if (aTs && bTs) return bTs.localeCompare(aTs);
    if (aTs) return -1;
    if (bTs) return 1;
    return String(a.username || "").localeCompare(String(b.username || ""));
  });

  if (!sortedFriends.length) {
    const empty       = document.createElement("li");
    empty.className   = "item-card list-empty";
    if (friends.length && query) {
      empty.textContent = `No chats match "${friendSearchQuery}"`;
    } else if (isMessagesView) {
      const byFilter = {
        all: "No chats yet - add friends or create a group",
        groups: "No groups yet - create one with the + button",
        blocked: "No blocked chats",
        unread: "No unread chats",
      };
      empty.textContent = byFilter[messageListFilter] || byFilter.all;
    } else {
      empty.textContent = friends.length
        ? `No chats match "${friendSearchQuery}"`
        : "No chats yet - add friends or create a group";
    }
    friendList.appendChild(empty);
    renderActiveFriendPresence();
    syncRemoveFriendButton();
    syncActiveConversationAccess();
    return;
  }

  const renderFriendRow = (friend) => {
    const li      = document.createElement("li");
    li.className  = "item-card";

    const btn         = document.createElement("button");
    btn.type          = "button";
    const chatKind = normalizeChatKind(friend?.kind || "friend");
    const blockedEntry = isBlockedFriendEntry(friend);
    const isActive = normalizeName(activeFriend) === normalizeName(friend.username)
      && normalizeChatKind(activeChatKind) === chatKind;
    btn.className     = `friend-btn chat-item${isActive ? " active" : ""}${blockedEntry ? " is-blocked" : ""}`;
    btn.dataset.username = friend.username;
    btn.dataset.kind = chatKind;

    // Avatar with initials + online dot
    const avatar        = document.createElement("div");
    const avatarPresenceMode = resolveFriendPresenceMode(friend);
    avatar.className    = `friend-avatar chat-av av-default${avatarPresenceMode !== "offline" ? " online" : ""}`;
    if (friend.avatarId && window._novynAvatarUtils) {
      window._novynAvatarUtils.applyAvatarToEl(avatar, friend.avatarId, getFriendDisplayName(friend).slice(0, 2).toUpperCase());
    } else {
      avatar.textContent = getFriendDisplayName(friend).slice(0, 2).toUpperCase();
    }
    btn.appendChild(avatar);

    const main      = document.createElement("div");
    main.className  = "friend-main chat-info";

    const name        = document.createElement("span");
    name.className    = "friend-name chat-name";
    name.textContent  = getFriendDisplayName(friend);
    if (chatKind === "group") {
      name.title = `${getFriendDisplayName(friend)} (#${friend.username})`;
    } else if (displayDiffersFromUsername(friend)) {
      name.title = `${getFriendDisplayName(friend)} (@${friend.username})`;
    } else {
      name.title = friend.username;
    }

    const preview = document.createElement("span");
    preview.className = "chat-preview";
    const isDirectMessage = chatKind === "friend";
    if (isContactsView) {
      preview.textContent = getFriendPresenceText(friend);
    } else if (isMessagesView && blockedEntry) {
      const safety = getFriendSafety(friend.username, chatKind);
      preview.textContent = safety.blockedByMe ? "Blocked by you" : "Blocked you";
    } else if (isMessagesView && isDirectMessage) {
      preview.textContent = getFriendPresenceText(friend);
    } else {
      preview.textContent = friendPreview(friend);
    }
    preview.title = preview.textContent;
    const showPresenceState = (isContactsView || (isMessagesView && isDirectMessage)) && !blockedEntry;
    const previewPresenceMode = resolveFriendPresenceMode(friend);
    preview.classList.toggle("status-online", showPresenceState && previewPresenceMode === "online");
    preview.classList.toggle("status-away", showPresenceState && previewPresenceMode === "away");
    preview.classList.toggle("status-busy", showPresenceState && previewPresenceMode === "busy");
    preview.classList.toggle("status-offline", showPresenceState && previewPresenceMode === "offline");

    const nameRow = document.createElement("div");
    nameRow.className = "chat-name-row";
    nameRow.appendChild(name);
    if (isMessagesView && chatKind === "group") {
      const chip = document.createElement("span");
      chip.className = "chat-kind-chip group";
      chip.textContent = "Group";
      nameRow.appendChild(chip);
    } else if (isMessagesView && blockedEntry) {
      const chip = document.createElement("span");
      chip.className = "chat-kind-chip blocked";
      chip.textContent = "Blocked";
      nameRow.appendChild(chip);
    }

    main.append(nameRow, preview);

    if (!isContactsView) {
      const side      = document.createElement("div");
      side.className  = "friend-side chat-right";

      if (!isMessagesView) {
        const timeText = formatFriendTime(friend.lastTimestamp);
        if (timeText) {
          const time = document.createElement("span");
          time.className = "chat-time";
          time.textContent = timeText;
          side.appendChild(time);
        }
      }
      const unreadCount = Number(friend.unreadCount) || 0;
      if (unreadCount > 0) {
        const unread        = document.createElement("span");
        unread.className    = "unread-badge";
        unread.textContent  = unreadCount > 99 ? "99+" : String(unreadCount);
        side.appendChild(unread);
      }

      if (side.childNodes.length) {
        btn.append(main, side);
      } else {
        btn.append(main);
      }
    } else {
      btn.append(main);
    }
    li.appendChild(btn);
    friendList.appendChild(li);
  };

  if (isContactsView) {
    const grouped = { online: [], away: [], busy: [], offline: [] };
    sortedFriends.forEach((friend) => {
      const bucket = getContactBucket(friend);
      if (grouped[bucket]) grouped[bucket].push(friend);
    });
    const order = ["online", "away", "busy", "offline"];
    const labels = { online: "Online", away: "Away", busy: "Busy", offline: "Offline" };

    order.forEach((bucket) => {
      const list = grouped[bucket];
      if (!list || !list.length) return;
      const label = document.createElement("li");
      label.className = "contact-section-label";
      label.textContent = `${labels[bucket]} - ${list.length}`;
      friendList.appendChild(label);
      list
        .slice()
        .sort((a, b) => getFriendDisplayName(a).localeCompare(getFriendDisplayName(b)))
        .forEach(renderFriendRow);
    });
  } else {
    sortedFriends.forEach(renderFriendRow);
  }

  renderActiveFriendPresence();
  syncRemoveFriendButton();
  syncActiveConversationAccess();
  renderCallHistory();
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Form handlers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Login button spinner helpers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
const loginBtn = document.getElementById("loginBtn");
const loginBtnText = loginBtn ? loginBtn.querySelector(".login-btn-text") : null;
const loginBtnArrow = loginBtn ? loginBtn.querySelector(".login-btn-arrow") : null;
const loginBtnSpinner = loginBtn ? loginBtn.querySelector(".login-btn-spinner") : null;

function setLoginLoading(isLoading) {
  if (!loginBtn) return;
  loginBtn.disabled = isLoading;
  if (loginBtnText)    loginBtnText.textContent = isLoading ? "Entering..." : "Sign In";
  if (loginBtnArrow)   loginBtnArrow.classList.toggle("hidden", isLoading);
  if (loginBtnSpinner) loginBtnSpinner.classList.toggle("hidden", !isLoading);
}

if (loginForm) {
  loginForm.addEventListener("submit", (e) => {
    e.preventDefault();
    // Legacy hidden login form is kept only for markup compatibility.
  });
}

// Clear suggestions as soon as the user starts editing
if (usernameInput) usernameInput.addEventListener("input", clearUsernameSuggestions);
if (passwordInput) passwordInput.addEventListener("input", clearUsernameSuggestions);

function requestFriendSuggestions(query) {
  if (!socketAvailable || !query) return;
  socket.emit("friend_search", { query });
}

if (addFriendForm) {
  addFriendForm.addEventListener("submit", (e) => {
    e.preventDefault();
    const val = friendInput ? friendInput.value.trim() : "";
    if (!val) return;
    if (me && normalizeName(val) === normalizeName(me)) {
      showToast("You can't add yourself!", "error");
      return;
    }
    socket.emit("add_friend", val);
    if (friendInput) friendInput.value = "";
    clearFriendSuggestions();
  });
}

if (friendInput) {
  friendInput.addEventListener("input", () => {
    const val = friendInput.value.trim();
    if (!val || val.length < 2) {
      clearFriendSuggestions();
      friendSuggestState.lastQuery = "";
      if (friendSuggestState.timer) clearTimeout(friendSuggestState.timer);
      return;
    }
    if (friendSuggestState.timer) clearTimeout(friendSuggestState.timer);
    friendSuggestState.timer = setTimeout(() => {
      friendSuggestState.lastQuery = val;
      requestFriendSuggestions(val);
    }, 220);
  });
  friendInput.addEventListener("blur", () => {
    setTimeout(() => {
      clearFriendSuggestions();
    }, 160);
  });
}

async function openCreateGroupPrompt() {
  const candidateFriends = friends.filter((entry) => normalizeChatKind(entry?.kind || "friend") === "friend");
  if (!candidateFriends.length) {
    showToast("Add at least one friend before creating a group.", "info");
    return;
  }
  const defaultName = `${getMyDisplayName()}'s group`;
  const groupNameInput = await appDialog.openPrompt({
    title: "Create group",
    description: "Choose a name for your new group chat.",
    label: "Group name",
    defaultValue: defaultName,
    placeholder: "Group name",
    confirmText: "Continue",
    multiline: false,
    maxLength: 48,
  });
  if (groupNameInput === null) return;
  const groupName = String(groupNameInput || "").trim().slice(0, 48);
  if (!groupName) {
    showToast("Group name is required.", "error");
    return;
  }

  const suggestedMembers = candidateFriends.slice(0, 5).map((entry) => entry.username).join(", ");
  const membersInput = await appDialog.openPrompt({
    title: "Add members",
    description: "Enter usernames separated by commas.",
    label: "Usernames",
    defaultValue: suggestedMembers,
    placeholder: "alice, bob, charlie",
    confirmText: "Create group",
    multiline: true,
    maxLength: 220,
  });
  if (membersInput === null) return;
  const allowed = new Set(candidateFriends.map((entry) => normalizeName(entry.username)));
  const members = Array.from(
    new Set(
      String(membersInput || "")
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean)
    )
  ).filter((username) => allowed.has(normalizeName(username)));
  if (!members.length) {
    showToast("Select at least one valid friend for the group.", "error");
    return;
  }

  socket.emit("create_group", {
    name: groupName,
    members,
  });
}

async function openAddGroupMembersPrompt() {
  if (!activeFriend || normalizeChatKind(activeChatKind) !== "group") {
    showToast("Open a group chat first.", "error");
    return;
  }
  const groupId = resolveGroupChatId(activeFriend, "group");
  if (!groupId) {
    showToast("Unable to resolve this group.", "error");
    return;
  }
  const groupInfo = getGroupInfo(groupId, "group");
  if (!groupInfo) {
    requestGroupInfo(groupId, { kind: "group", force: true });
  }
  if (groupInfo && !(groupInfo.me?.isAdmin || groupInfo.me?.isOwner)) {
    showToast("Only group admins can add members.", "error");
    return;
  }

  const existingMembers = new Set((groupInfo?.members || []).map((member) => normalizeName(member.username)));
  const candidateFriends = friends.filter((entry) => {
    if (normalizeChatKind(entry?.kind || "friend") !== "friend") return false;
    const key = normalizeName(entry.username);
    if (!key || existingMembers.has(key)) return false;
    if (entry?.blockedByMe || entry?.blockedYou) return false;
    return true;
  });
  if (!candidateFriends.length) {
    showToast("No eligible friends to add.", "info");
    return;
  }

  const suggestedMembers = candidateFriends.slice(0, 6).map((entry) => entry.username).join(", ");
  const membersInput = await appDialog.openPrompt({
    title: "Add members",
    description: "Enter usernames separated by commas.",
    label: "Usernames",
    defaultValue: suggestedMembers,
    placeholder: "alice, bob, charlie",
    confirmText: "Send invites",
    multiline: true,
    maxLength: 260,
  });
  if (membersInput === null) return;
  const allowed = new Set(candidateFriends.map((entry) => normalizeName(entry.username)));
  const members = Array.from(
    new Set(
      String(membersInput || "")
        .split(",")
        .map((value) => value.trim().replace(/^@+/, ""))
        .filter(Boolean)
    )
  ).filter((username) => allowed.has(normalizeName(username)));
  if (!members.length) {
    showToast("Select at least one valid friend to add.", "error");
    return;
  }

  socket.emit("add_group_members", {
    groupId,
    members,
  });
  if (!groupInfo) {
    showToast("Invites sent. Refreshing group members...", "success");
    requestGroupInfo(groupId, { kind: "group", force: true });
  }
}

if (createGroupBtn) {
  createGroupBtn.addEventListener("click", () => {
    openCreateGroupPrompt();
  });
}

if (chatCategoryButtons.length) {
  chatCategoryButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      const filter = String(btn.dataset.chatFilter || "all").trim();
      if (sidebarView !== "messages") {
        switchRail("messages");
      }
      setMessageListFilter(filter);
    });
  });
}

if (chatQuickMenuBtn && chatQuickMenu) {
  chatQuickMenuBtn.addEventListener("click", (event) => {
    event.preventDefault();
    event.stopPropagation();
    toggleChatQuickMenu();
  });
  chatQuickMenu.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof Element)) return;
    const item = target.closest(".chat-quick-item");
    if (!item) return;
    if (item instanceof HTMLButtonElement && item.disabled) return;
    const action = String(item.dataset.quickAction || "").trim();
    closeChatQuickMenu();
    if (action === "profile") {
      setSettingsOpen(true);
      return;
    }
    if (action === "discover") {
      switchRail("discover");
      return;
    }
    if (action === "clear-chat") {
      void requestClearActiveChat();
      return;
    }
    if (["all", "groups", "blocked", "unread"].includes(action)) {
      if (sidebarView !== "messages") {
        switchRail("messages");
      }
      setMessageListFilter(action);
    }
  });
}

if (sidebarSearch) {
  const applyFriendSearch = () => {
    friendSearchQuery = normalizeSearchText(sidebarSearch.value);
    renderRequests();
    renderFriends();
    renderCallHistory();
    renderDiscover();
  };
  sidebarSearch.addEventListener("input", applyFriendSearch);
  sidebarSearch.addEventListener("search", applyFriendSearch);
}

if (navRailButtons.length) {
  navRailButtons.forEach((btn) => {
    btn.addEventListener("click", (e) => {
      const view = btn.dataset.rail || "";
      if (!view) return;
      if (view === "settings") {
        if (e) e.stopPropagation();
        setSettingsOpen(!settingsOpen);
        return;
      }
      switchRail(view);
    });
  });
  window.__novynNavBound = true;
}

if (callFilterButtons.length) {
  callFilterButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      const filter = btn.dataset.callFilter || "all";
      setCallFilter(filter);
    });
  });
}

if (settingsPanel) {
  settingsPanel.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof Element)) return;
    const btn = target.closest(".status-pill[data-status]");
    if (!btn || !settingsPanel.contains(btn)) return;
    const requested = normalizePresenceMode(btn.dataset.status, myPresenceMode);
    setMyPresenceMode(requested, { emit: true, toast: true, manual: true });
  });
}

if (settingsCloseBtn) {
  settingsCloseBtn.addEventListener("click", () => setSettingsOpen(false));
}

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && settingsOpen) {
    setSettingsOpen(false);
    return;
  }
  if (e.key === "Escape") {
    closeChatQuickMenu();
  }
});

document.addEventListener("click", (event) => {
  if (!chatQuickMenu || chatQuickMenu.classList.contains("hidden")) return;
  const target = event.target;
  if (!(target instanceof Element)) return;
  const insideMenu = Boolean(target.closest("#chatQuickMenu"));
  const insideButton = Boolean(target.closest("#chatQuickMenuBtn"));
  if (insideMenu || insideButton) return;
  closeChatQuickMenu();
});

if (mobBackBtn) {
  mobBackBtn.addEventListener("click", () => {
    clearActiveFriendSelection();
    showSidebarOnMobile();
  });
}

document.addEventListener("visibilitychange", () => {
  if (!isDashboardPage) return;
  if (document.hidden) {
    cameraCaptureModal.close();
    closeStatusViewer();
    setActiveChatTarget("");
  } else if (activeFriend) {
    setActiveChatTarget(activeFriend);
  }
  markPresenceActivity({ skipThrottle: true });
});

if (isDashboardPage) {
  const presenceActivityEvents = ["pointerdown", "keydown", "touchstart", "mousemove", "wheel"];
  presenceActivityEvents.forEach((eventName) => {
    const listenerOptions = eventName === "keydown" ? undefined : { passive: true };
    document.addEventListener(eventName, () => {
      markPresenceActivity();
    }, listenerOptions);
  });
}

if (storiesRow) {
  const activateStoryItem = async (item) => {
    if (!item) return;
    const action = String(item.dataset.storyAction || "").trim();
    if (action === "my-status") {
      if (readMyStatusEntry()) {
        openStatusViewerByUsername(me, { includeMine: true });
        return;
      }
      await promptForMyStatus({ openViewer: true });
      return;
    }
    if (action !== "status") return;
    const username = String(item.dataset.storyUsername || "").trim();
    if (!username) return;
    openStatusViewerByUsername(username);
  };

  storiesRow.addEventListener("click", (e) => {
    const target = e.target;
    if (!(target instanceof Element)) return;
    const item = target.closest(".story-item");
    if (!item || !storiesRow.contains(item)) return;
    e.preventDefault();
    void activateStoryItem(item);
  });

  storiesRow.addEventListener("keydown", (e) => {
    if (e.key !== "Enter" && e.key !== " ") return;
    const target = e.target;
    if (!(target instanceof Element)) return;
    const item = target.closest(".story-item");
    if (!item || !storiesRow.contains(item)) return;
    e.preventDefault();
    void activateStoryItem(item);
  });
}

if (statusViewerBackdrop) {
  statusViewerBackdrop.addEventListener("click", () => closeStatusViewer());
}
if (statusViewerCloseBtn) {
  statusViewerCloseBtn.addEventListener("click", () => closeStatusViewer());
}
if (statusViewerPrevBtn) {
  statusViewerPrevBtn.addEventListener("click", (e) => {
    e.preventDefault();
    stepStatusViewer(-1);
  });
}
if (statusViewerNextBtn) {
  statusViewerNextBtn.addEventListener("click", (e) => {
    e.preventDefault();
    stepStatusViewer(1);
  });
}
if (statusViewerEditBtn) {
  statusViewerEditBtn.addEventListener("click", async (e) => {
    e.preventDefault();
    const updated = await promptForMyStatus({ openViewer: false });
    if (!updated) return;
    openStatusViewerByUsername(me, { includeMine: true });
  });
}
document.addEventListener("keydown", (e) => {
  if (!statusViewerModal || statusViewerModal.classList.contains("hidden")) return;
  if (e.key === "Escape") {
    e.preventDefault();
    closeStatusViewer();
    return;
  }
  if (e.key === "ArrowLeft") {
    e.preventDefault();
    stepStatusViewer(-1);
    return;
  }
  if (e.key === "ArrowRight") {
    e.preventDefault();
    stepStatusViewer(1);
  }
});

if (friendList) {
  const handleFriendActivate = (e) => {
    const btn = e.target.closest(".friend-btn");
    if (!btn) return;
    const username = btn.dataset.username;
    const kind = normalizeChatKind(btn.dataset.kind || "friend");
    if (!username) return;
    e.preventDefault();
    setActiveFriend(username, kind);
    showChatOnMobile();
  };
  friendList.addEventListener("click", handleFriendActivate);
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Custom unfriend confirm modal Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
const unfriendModal  = document.getElementById("unfriendModal");
const unfriendCancel  = document.getElementById("unfriendCancel");
const unfriendConfirm = document.getElementById("unfriendConfirm");
const unfriendModalTitle = document.getElementById("unfriendModalTitle");
const unfriendModalDesc  = document.getElementById("unfriendModalDesc");
let pendingUnfriendTarget = "";
let unfriendFocusReturn = null;
let unfriendTrapCleanup = null;

function getModalFocusable(modal) {
  if (!modal) return [];
  const nodes = modal.querySelectorAll("button, [href], input, select, textarea, [tabindex]:not([tabindex='-1'])");
  return Array.from(nodes).filter((el) => !el.disabled && el.offsetParent !== null);
}

function trapModalFocus(modal) {
  const onKey = (e) => {
    if (e.key !== "Tab") return;
    const focusable = getModalFocusable(modal);
    if (!focusable.length) return;
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  };
  modal.addEventListener("keydown", onKey);
  return () => modal.removeEventListener("keydown", onKey);
}

function showUnfriendModal(target) {
  pendingUnfriendTarget = target;
  if (unfriendModalTitle) unfriendModalTitle.textContent = `Unfriend @${target}?`;
  if (unfriendModalDesc)  unfriendModalDesc.textContent  = `This will also clear your chat history with @${target}.`;
  if (unfriendModal) {
    unfriendFocusReturn = document.activeElement;
    unfriendModal.style.display = "flex";
    if (unfriendTrapCleanup) unfriendTrapCleanup();
    unfriendTrapCleanup = trapModalFocus(unfriendModal);
    const focusable = getModalFocusable(unfriendModal);
    if (focusable.length) focusable[0].focus();
  }
}
function hideUnfriendModal() {
  if (unfriendModal) unfriendModal.style.display = "none";
  if (unfriendTrapCleanup) {
    unfriendTrapCleanup();
    unfriendTrapCleanup = null;
  }
  if (unfriendFocusReturn && typeof unfriendFocusReturn.focus === "function") {
    unfriendFocusReturn.focus();
  }
  unfriendFocusReturn = null;
  pendingUnfriendTarget = "";
}

if (unfriendCancel)  unfriendCancel.addEventListener("click", hideUnfriendModal);
if (unfriendConfirm) unfriendConfirm.addEventListener("click", () => {
  if (pendingUnfriendTarget) socket.emit("remove_friend", pendingUnfriendTarget);
  hideUnfriendModal();
});
if (unfriendModal) {
  unfriendModal.querySelector(".confirm-modal-backdrop")
    ?.addEventListener("click", hideUnfriendModal);
}
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && unfriendModal && unfriendModal.style.display !== "none") {
    hideUnfriendModal();
  }
});

if (removeFriendBtn) {
  removeFriendBtn.addEventListener("click", async () => {
    if (!activeFriend) return;
    const activeEntry = getActiveChatEntry();
    const isGroup = normalizeChatKind(activeEntry?.kind || activeChatKind) === "group";
    if (isGroup) {
      const label = getFriendDisplayName(activeEntry || { username: activeFriend });
      const confirmed = await appDialog.openConfirm({
        title: `Leave "${label}"?`,
        description: "You can be re-added to this group later by an admin.",
        confirmText: "Leave group",
        danger: true,
      });
      if (!confirmed) return;
      socket.emit("leave_group", { groupId: activeFriend });
      return;
    }
    showUnfriendModal(activeFriend);
  });
}

if (clearChatBtn) {
  clearChatBtn.addEventListener("click", () => {
    void requestClearActiveChat();
  });
}

function keepComposerFocused() {
  if (!messageInput || messageInput.disabled) return;

  const refocus = () => {
    try {
      messageInput.focus({ preventScroll: true });
    } catch (_) {
      messageInput.focus();
    }
    const caretPos = messageInput.value.length;
    if (typeof messageInput.setSelectionRange === "function") {
      messageInput.setSelectionRange(caretPos, caretPos);
    }
  };

  // First immediate focus, then a delayed pass for mobile keyboards.
  refocus();
  setTimeout(refocus, 40);
}

const voiceState = {
  recorder: null,
  chunks: [],
  stream: null,
  timeout: null,
  isRecording: false,
  uploading: false,
  cancelNext: false,
  startedAt: 0,
  timerId: null,
  pendingTempId: "",
  activitySent: false,
  activityTarget: "",
  activityKind: "friend",
  activityPingId: null,
};

const DEFAULT_ICE_SERVERS = [
  { urls: "stun:stun.l.google.com:19302" },
  { urls: "stun:stun1.l.google.com:19302" },
];
const CALL_SIGNAL_RETRY_MS = 2200;
const CALL_SIGNAL_MAX_ATTEMPTS = 8;
const CALL_RING_TIMEOUT_MS = 30000;

function sanitizeIceServerList(input) {
  if (!Array.isArray(input)) return [];
  const normalized = [];
  for (const entry of input) {
    if (!entry || typeof entry !== "object") continue;
    const rawUrls = entry.urls;
    let urls = "";
    if (typeof rawUrls === "string") {
      urls = rawUrls.trim();
    } else if (Array.isArray(rawUrls)) {
      urls = rawUrls.map((value) => String(value || "").trim()).filter(Boolean);
    }
    if (!urls || (Array.isArray(urls) && !urls.length)) continue;
    const server = { urls };
    if (typeof entry.username === "string" && entry.username.trim()) {
      server.username = entry.username.trim();
    }
    if (typeof entry.credential === "string" && entry.credential.length) {
      server.credential = entry.credential;
    }
    if (typeof entry.credentialType === "string" && entry.credentialType.trim()) {
      server.credentialType = entry.credentialType.trim();
    }
    normalized.push(server);
  }
  return normalized;
}

let callIceServers = sanitizeIceServerList(window.NOVYN_ICE_SERVERS);
if (!callIceServers.length) {
  callIceServers = DEFAULT_ICE_SERVERS.slice();
}
let callIceServersReady = false;
let callIceConfigPromise = null;

async function ensureCallIceServers(force = false) {
  if (callIceServersReady && !force) return callIceServers;
  if (callIceConfigPromise && !force) return callIceConfigPromise;

  callIceConfigPromise = (async () => {
    let loadedFromApi = false;
    try {
      let result = null;
      if (authApi?.request) {
        result = await authApi.request("/api/rtc/ice", {
          method: "GET",
          cache: "no-store",
        });
      } else {
        const response = await fetch("/api/rtc/ice", {
          method: "GET",
          cache: "no-store",
          credentials: "same-origin",
        });
        const data = await response.json().catch(() => ({}));
        result = { ok: response.ok, status: response.status, data };
      }
      if (result?.ok) {
        const remoteServers = sanitizeIceServerList(result?.data?.iceServers);
        if (remoteServers.length) {
          callIceServers = remoteServers;
        }
        loadedFromApi = true;
      }
    } catch (_) {
      // Keep default STUN servers when API lookup fails.
    } finally {
      callIceServersReady = loadedFromApi;
      callIceConfigPromise = null;
    }
    return callIceServers;
  })();

  return callIceConfigPromise;
}

if (isDashboardPage) {
  void ensureCallIceServers();
}

const callState = {
  status: "idle",
  peer: "",
  pc: null,
  localStream: null,
  remoteStream: null,
  pendingOffer: null,
  pendingLocalOffer: null,
  pendingLocalAnswer: null,
  lastRemoteOfferSdp: "",
  lastRemoteAnswerSdp: "",
  pendingCandidates: [],
  isCaller: false,
  inviteAcknowledged: false,
  muted: false,
  speakerOn: true,
  mediaType: "audio",
  videoEnabled: true,
  videoFacing: "user",
  startedAt: 0,
  timerId: null,
  minimized: false,
  logSent: false,
  reconnectTimer: null,
  ringTimeoutTimer: null,
  offerRetryTimer: null,
  answerRetryTimer: null,
  offerRetryCount: 0,
  answerRetryCount: 0,
};

const remoteSpeakingState = {
  context: null,
  analyser: null,
  source: null,
  data: null,
  rafId: 0,
  speakingFrames: 0,
  silentFrames: 0,
  speaking: false,
};
const speakingIndicatorState = {
  source: "none",
};

function resetVoiceState() {
  if (voiceState.activitySent) {
    emitVoiceActivity(
      false,
      voiceState.activityTarget || activeFriend,
      voiceState.activityKind || activeChatKind
    );
  }
  if (voiceState.timeout) clearTimeout(voiceState.timeout);
  voiceState.timeout = null;
  if (voiceState.timerId) clearInterval(voiceState.timerId);
  voiceState.timerId = null;
  if (voiceState.activityPingId) clearInterval(voiceState.activityPingId);
  voiceState.activityPingId = null;
  if (voiceState.recorder && voiceState.recorder.state !== "inactive") {
    voiceState.recorder.stop();
  }
  if (voiceState.stream) {
    voiceState.stream.getTracks().forEach((t) => t.stop());
  }
  voiceState.recorder = null;
  voiceState.stream = null;
  voiceState.chunks = [];
  voiceState.isRecording = false;
  voiceState.cancelNext = false;
  voiceState.startedAt = 0;
  voiceState.pendingTempId = "";
  voiceState.activitySent = false;
  voiceState.activityTarget = "";
  voiceState.activityKind = "friend";
  if (voiceBtn) {
    voiceBtn.classList.remove("recording");
    voiceBtn.setAttribute("aria-pressed", "false");
    voiceBtn.disabled = messageInput?.disabled;
    voiceBtn.title = "Voice message";
  }
  if (voiceStatus) {
    voiceStatus.classList.add("hidden");
    voiceStatus.dataset.state = "idle";
  }
  if (voiceLabel) voiceLabel.textContent = "Recording...";
  if (voiceTimer) voiceTimer.textContent = "0:00";
  if (voiceProgress) voiceProgress.classList.add("hidden");
  if (voiceProgressBar) voiceProgressBar.style.transform = "scaleX(0)";
  if (voiceProgressText) voiceProgressText.textContent = "Uploading... 0%";
  if (voiceCancelBtn) voiceCancelBtn.disabled = false;
  if (voiceStopBtn) voiceStopBtn.disabled = false;
  if (callState.status !== "active") {
    hideSpeakingIndicator("voice-note");
  }
}

function setAttachmentUploadUiState(isUploading) {
  attachmentUploadState.active = Boolean(isUploading);
  syncAttachButtonState();
}

async function uploadAttachmentFile(file) {
  if (!file) throw new Error("No file selected.");
  const formData = new FormData();
  formData.append("file", file, file.name || `attachment-${Date.now()}`);

  const response = await fetch("/upload-file", {
    method: "POST",
    headers: buildCsrfHeaders(),
    body: formData,
    credentials: "same-origin",
  });

  let payload = {};
  try {
    payload = await response.json();
  } catch (_) {
    payload = {};
  }

  if (!response.ok) {
    throw new Error(payload?.error || "File upload failed.");
  }

  const attachment = normalizeAttachmentPayload(payload, payload?.url || "");
  if (!attachment) {
    throw new Error("Upload finished but no file URL was returned.");
  }
  return attachment;
}

async function uploadAttachmentFromPicker(file) {
  if (!file) return;
  if (!activeFriend) {
    showToast("Choose a friend before attaching a file.", "error");
    return;
  }
  const safety = getFriendSafety(activeFriend, activeChatKind);
  if (safety.blocked) {
    showToast(safety.blockedByMe ? "Unblock this contact to share files." : "This user has blocked you.", "error");
    return;
  }
  if (attachmentUploadState.active) {
    showToast("Please wait for the current upload to finish.", "info");
    return;
  }
  if (Number(file.size || 0) > ATTACHMENT_MAX_SIZE_BYTES) {
    showToast("File is too large. Max size is 15 MB.", "error");
    return;
  }

  const targetFriend = activeFriend;
  const targetKind = normalizeChatKind(activeChatKind);
  if (hasNewerMessages()) {
    showLatestMessages();
  }
  const tempId = createClientTempId();
  attachmentUploadState.pendingTempId = tempId;
  attachmentUploadState.target = targetFriend;
  setAttachmentUploadUiState(true);

  const pendingLabel = `Uploading ${String(file.name || "file").slice(0, 120)}...`;
  queuePendingMessage(
    { to: targetFriend, toType: targetKind, text: pendingLabel, clientTempId: tempId },
    { queue: false, updateFriends: false }
  );
  pinConversationToBottom();

  try {
    const attachment = await uploadAttachmentFile(file);
    if (attachmentUploadState.pendingTempId) {
      const pendingTempId = attachmentUploadState.pendingTempId;
      attachmentUploadState.pendingTempId = "";
      updatePendingMessageAttachment(pendingTempId, attachment, attachment.url);
      sendMessagePayload(
        {
          to: targetFriend,
          toType: targetKind,
          text: attachment.url,
          attachment,
          clientTempId: pendingTempId,
        },
        { optimistic: false }
      );
    } else {
      sendMessagePayload({ to: targetFriend, toType: targetKind, text: attachment.url, attachment });
    }
    pinConversationToBottom();
    showToast(attachment.kind === "image" ? "Image sent." : "File sent.", "success");
  } catch (error) {
    console.error(error);
    if (attachmentUploadState.pendingTempId) {
      removePendingMessage(attachmentUploadState.pendingTempId);
    }
    const message = String(error?.message || "File upload failed.");
    showToast(message, "error");
  } finally {
    attachmentUploadState.pendingTempId = "";
    attachmentUploadState.target = "";
    setAttachmentUploadUiState(false);
    if (attachFileInput) {
      attachFileInput.value = "";
    }
    if (cameraCaptureInput) {
      cameraCaptureInput.value = "";
    }
  }
}

async function uploadVoiceBlob(blob, options = {}) {
  if (!blob || !activeFriend) return;
  const safety = getFriendSafety(activeFriend, activeChatKind);
  if (safety.blocked) {
    showToast(safety.blockedByMe ? "Unblock this contact to send voice messages." : "This user has blocked you.", "error");
    return;
  }
  const targetFriend = activeFriend;
  const targetKind = normalizeChatKind(activeChatKind);
  if (hasNewerMessages()) {
    showLatestMessages();
  }
  voiceState.uploading = true;
  if (voiceStatus) {
    voiceStatus.classList.remove("hidden");
    voiceStatus.dataset.state = "uploading";
  }
  if (voiceLabel) voiceLabel.textContent = "Uploading...";
  if (voiceProgress) voiceProgress.classList.remove("hidden");
  if (voiceProgressBar) voiceProgressBar.style.transform = "scaleX(0)";
  if (voiceProgressText) voiceProgressText.textContent = "Uploading... 0%";
  if (voiceCancelBtn) voiceCancelBtn.disabled = true;
  if (voiceStopBtn) voiceStopBtn.disabled = true;
  if (targetFriend) {
    const tempId = createClientTempId();
    voiceState.pendingTempId = tempId;
    queuePendingMessage(
      { to: targetFriend, toType: targetKind, text: "Uploading voice message...", clientTempId: tempId },
      { queue: false, updateFriends: false }
    );
  }
  try {
    const formData = new FormData();
    const sourceMime = String(options.mimeType || blob.type || "").toLowerCase().trim();
    const uploadMime = sourceMime || "audio/webm";
    const ext = getVoiceFileExtension(uploadMime);
    const voicePayload = blob.type ? blob : new Blob([blob], { type: uploadMime });
    formData.append("voice", voicePayload, `voice-${Date.now()}${ext}`);
    const data = await new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open("POST", "/upload-voice");
      const csrfToken = readCookie(CSRF_COOKIE_NAME);
      if (csrfToken) {
        xhr.setRequestHeader(CSRF_HEADER_NAME, csrfToken);
      }
      xhr.upload.onprogress = (evt) => {
        if (!evt.lengthComputable) return;
        const pct = Math.max(0, Math.min(1, evt.loaded / evt.total));
        if (voiceProgressBar) voiceProgressBar.style.transform = `scaleX(${pct})`;
        if (voiceProgressText) voiceProgressText.textContent = `Uploading... ${Math.round(pct * 100)}%`;
      };
      xhr.onload = () => {
        const isOk = xhr.status >= 200 && xhr.status < 300;
        let payload = {};
        try { payload = JSON.parse(xhr.responseText || "{}"); } catch (_) {}
        if (!isOk) {
          reject(new Error(payload?.error || "Upload failed"));
          return;
        }
        resolve(payload);
      };
      xhr.onerror = () => reject(new Error("Upload failed"));
      xhr.send(formData);
    });
    if (!data?.url) throw new Error("No URL returned");
    if (voiceState.pendingTempId) {
      const tempId = voiceState.pendingTempId;
      voiceState.pendingTempId = "";
      updatePendingMessageText(tempId, data.url);
      const pendingMsg = pendingByTempId.get(tempId);
      if (pendingMsg) {
        friends = friends.map((f) =>
          normalizeName(f.username) === normalizeName(targetFriend)
            ? { ...f, lastMessage: pendingMsg.text, lastFrom: me, lastTimestamp: pendingMsg.timestamp }
            : f
        );
        renderFriends();
      }
      sendMessagePayload({ to: targetFriend, toType: targetKind, text: data.url, clientTempId: tempId }, { optimistic: false });
    } else {
      sendMessagePayload({ to: targetFriend, toType: targetKind, text: data.url });
    }
    pinConversationToBottom();
    showToast("Voice message sent", "success");
  } catch (err) {
    console.error(err);
    if (voiceState.pendingTempId) {
      removePendingMessage(voiceState.pendingTempId);
      voiceState.pendingTempId = "";
    }
    showToast("Voice upload failed", "error");
  } finally {
    voiceState.uploading = false;
    if (voiceProgress) voiceProgress.classList.add("hidden");
    if (voiceCancelBtn) voiceCancelBtn.disabled = false;
    if (voiceStopBtn) voiceStopBtn.disabled = false;
    if (voiceStatus) {
      voiceStatus.classList.add("hidden");
      voiceStatus.dataset.state = "idle";
    }
  }
}

function stopVoiceRecording(cancelled = false) {
  if (!voiceState.isRecording) return;
  voiceState.isRecording = false;
  voiceState.cancelNext = cancelled;
  if (voiceState.activityPingId) {
    clearInterval(voiceState.activityPingId);
    voiceState.activityPingId = null;
  }
  if (voiceState.activitySent) {
    emitVoiceActivity(
      false,
      voiceState.activityTarget || activeFriend,
      voiceState.activityKind || activeChatKind
    );
    voiceState.activitySent = false;
  }
  if (voiceState.timeout) clearTimeout(voiceState.timeout);
  voiceState.timeout = null;
  if (voiceState.recorder && voiceState.recorder.state !== "inactive") {
    voiceState.recorder.stop();
  }
  if (voiceBtn) {
    voiceBtn.classList.remove("recording");
    voiceBtn.setAttribute("aria-pressed", "false");
  }
}

async function startVoiceRecording() {
  if (!voiceBtn) return;
  if (!activeFriend) {
    showToast("Choose a friend before recording.", "error");
    return;
  }
  const safety = getFriendSafety(activeFriend, activeChatKind);
  if (safety.blocked) {
    showToast(safety.blockedByMe ? "Unblock this contact to record voice." : "This user has blocked you.", "error");
    return;
  }
  if (!navigator.mediaDevices?.getUserMedia) {
    showToast("Voice recording not supported in this browser.", "error");
    return;
  }
  if (voiceState.uploading) {
    showToast("Voice upload in progress. Please wait.", "info");
    return;
  }

  stopLocalTyping(activeFriend, activeChatKind);

  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const preferredMimeType = getSupportedVoiceMimeType();
    const recorder = preferredMimeType
      ? new MediaRecorder(stream, { mimeType: preferredMimeType })
      : new MediaRecorder(stream);

    voiceState.stream = stream;
    voiceState.recorder = recorder;
    voiceState.chunks = [];
    voiceState.isRecording = true;
    voiceState.cancelNext = false;
    voiceState.startedAt = Date.now();
    voiceState.activitySent = false;
    voiceState.activityTarget = activeFriend;
    voiceState.activityKind = normalizeChatKind(activeChatKind);

    recorder.ondataavailable = (evt) => {
      if (evt?.data?.size > 0) voiceState.chunks.push(evt.data);
    };
    recorder.onstop = async () => {
      const recordedMime = String(
        recorder.mimeType || preferredMimeType || voiceState.chunks?.[0]?.type || "audio/webm"
      ).toLowerCase();
      const blob = new Blob(voiceState.chunks, { type: recordedMime });
      const cancelled = voiceState.cancelNext;
      resetVoiceState();
      if (cancelled) {
        showToast("Recording discarded", "info");
        return;
      }
      if (!blob.size) {
        showToast("Recording is empty. Try again.", "error");
        return;
      }
      await uploadVoiceBlob(blob, { mimeType: recordedMime });
    };

    recorder.start();
    voiceBtn.classList.add("recording");
    voiceBtn.setAttribute("aria-pressed", "true");
    voiceBtn.title = "Stop recording";
    if (voiceStatus) {
      voiceStatus.classList.remove("hidden");
      voiceStatus.dataset.state = "recording";
    }
    if (voiceLabel) {
      voiceLabel.textContent = "Recording voice note...";
    }
    if (callState.status !== "active") {
      // Receiver-only speaking indicator: don't show this local chip to sender.
      hideSpeakingIndicator("voice-note");
      emitVoiceActivity(true, voiceState.activityTarget, voiceState.activityKind);
      voiceState.activitySent = true;
      if (voiceState.activityPingId) clearInterval(voiceState.activityPingId);
      voiceState.activityPingId = setInterval(() => {
        if (!voiceState.isRecording || !voiceState.activitySent) return;
        emitVoiceActivity(true, voiceState.activityTarget, voiceState.activityKind);
      }, 1400);
    }
    if (voiceTimer) voiceTimer.textContent = "0:00";
    if (voiceProgress) voiceProgress.classList.add("hidden");
    if (voiceProgressBar) voiceProgressBar.style.transform = "scaleX(0)";
    if (voiceProgressText) voiceProgressText.textContent = "Uploading... 0%";
    if (voiceCancelBtn) voiceCancelBtn.disabled = false;
    if (voiceStopBtn) voiceStopBtn.disabled = false;

    if (voiceState.timerId) clearInterval(voiceState.timerId);
    voiceState.timerId = setInterval(() => {
      if (!voiceState.startedAt) return;
      const secs = Math.max(0, Math.floor((Date.now() - voiceState.startedAt) / 1000));
      const mins = Math.floor(secs / 60);
      const rem = String(secs % 60).padStart(2, "0");
      if (voiceTimer) voiceTimer.textContent = `${mins}:${rem}`;
    }, 500);

    voiceState.timeout = setTimeout(() => {
      showToast("Recording auto-stopped at 60s", "info");
      stopVoiceRecording();
    }, 60000);
  } catch (err) {
    console.error(err);
    resetVoiceState();
    showToast("Microphone permission blocked.", "error");
  }
}

function getCallPeerDisplayName(peer) {
  if (!peer) return "Friend";
  const friend = findFriend(peer);
  return friend ? getFriendDisplayName(friend) : peer;
}

function getCallStatusLabel() {
  if (callState.status === "outgoing") return "Calling...";
  if (callState.status === "ringing") return "Ringing...";
  if (callState.status === "incoming") return "Incoming call";
  if (callState.status === "connecting") return "Connecting...";
  if (callState.status === "reconnecting") return "Reconnecting...";
  if (callState.status === "active") return "In call";
  return "Call";
}

function getCallDurationSeconds() {
  if (!callState.startedAt) return 0;
  return Math.max(0, Math.floor((Date.now() - callState.startedAt) / 1000));
}

function updateCallTimer() {
  if (!callDurationText && !callMiniTime) return;
  if (!callState.startedAt) {
    if (callDurationText) callDurationText.classList.add("hidden");
    if (callMiniTime) callMiniTime.classList.add("hidden");
    return;
  }
  const formatted = formatCallDuration(getCallDurationSeconds());
  if (callDurationText) {
    callDurationText.textContent = formatted;
    callDurationText.classList.remove("hidden");
  }
  if (callMiniTime) {
    callMiniTime.textContent = formatted;
    callMiniTime.classList.remove("hidden");
  }
}

function startCallTimer() {
  if (callState.startedAt) return;
  callState.startedAt = Date.now();
  updateCallTimer();
  callState.timerId = setInterval(updateCallTimer, 1000);
}

function stopCallTimer() {
  if (callState.timerId) clearInterval(callState.timerId);
  callState.timerId = null;
  callState.startedAt = 0;
  if (callDurationText) {
    callDurationText.textContent = "00:00";
    callDurationText.classList.add("hidden");
  }
  if (callMiniTime) {
    callMiniTime.textContent = "00:00";
    callMiniTime.classList.add("hidden");
  }
}

function clearReconnectTimer() {
  if (callState.reconnectTimer) clearTimeout(callState.reconnectTimer);
  callState.reconnectTimer = null;
}

function clearCallRingTimeout() {
  if (callState.ringTimeoutTimer) clearTimeout(callState.ringTimeoutTimer);
  callState.ringTimeoutTimer = null;
}

function clearOfferRetry(preserveOffer = false) {
  if (callState.offerRetryTimer) clearTimeout(callState.offerRetryTimer);
  callState.offerRetryTimer = null;
  callState.offerRetryCount = 0;
  if (!preserveOffer) callState.pendingLocalOffer = null;
}

function clearAnswerRetry(preserveAnswer = false) {
  if (callState.answerRetryTimer) clearTimeout(callState.answerRetryTimer);
  callState.answerRetryTimer = null;
  callState.answerRetryCount = 0;
  if (!preserveAnswer) callState.pendingLocalAnswer = null;
}

function startOutgoingCallTimeout() {
  clearCallRingTimeout();
  callState.ringTimeoutTimer = setTimeout(() => {
    if (!callState.isCaller || !["outgoing", "ringing", "connecting"].includes(callState.status)) return;
    showToast("Call request timed out.", "info");
    maybeSendCallLog("unavailable");
    resetCallState();
  }, CALL_RING_TIMEOUT_MS);
}

function scheduleOfferRetry() {
  if (!callState.pendingLocalOffer || !callState.peer) return;
  if (!["outgoing", "ringing", "connecting"].includes(callState.status)) return;

  if (callState.offerRetryCount >= CALL_SIGNAL_MAX_ATTEMPTS) {
    showToast("Unable to reach your friend right now.", "error");
    maybeSendCallLog("unavailable");
    resetCallState();
    return;
  }

  callState.offerRetryCount += 1;
  if (!callState.inviteAcknowledged) {
    socket.emit("call_invite", { to: callState.peer, type: callState.mediaType });
  }
  socket.emit("call_signal", {
    to: callState.peer,
    type: "offer",
    sdp: callState.pendingLocalOffer,
  });

  if (callState.offerRetryTimer) clearTimeout(callState.offerRetryTimer);
  callState.offerRetryTimer = setTimeout(scheduleOfferRetry, CALL_SIGNAL_RETRY_MS);
}

function startOfferRetry(localDescription) {
  if (!localDescription) return;
  callState.pendingLocalOffer = localDescription;
  clearOfferRetry(true);
  scheduleOfferRetry();
}

function scheduleAnswerRetry() {
  if (!callState.pendingLocalAnswer || !callState.peer) return;
  if (callState.status === "idle" || callState.status === "active") return;

  if (callState.answerRetryCount >= CALL_SIGNAL_MAX_ATTEMPTS) {
    showToast("Couldn't complete call handshake.", "error");
    socket.emit("call_reject", { to: callState.peer });
    resetCallState();
    return;
  }

  callState.answerRetryCount += 1;
  socket.emit("call_signal", {
    to: callState.peer,
    type: "answer",
    sdp: callState.pendingLocalAnswer,
  });

  if (callState.answerRetryTimer) clearTimeout(callState.answerRetryTimer);
  callState.answerRetryTimer = setTimeout(scheduleAnswerRetry, CALL_SIGNAL_RETRY_MS);
}

function startAnswerRetry(localDescription) {
  if (!localDescription) return;
  callState.pendingLocalAnswer = localDescription;
  clearAnswerRetry(true);
  scheduleAnswerRetry();
}

function scheduleReconnectTimeout() {
  if (callState.reconnectTimer) return;
  callState.reconnectTimer = setTimeout(() => {
    if (callState.status !== "reconnecting") return;
    showToast("Call lost.", "info");
    maybeSendCallLog("ended");
    resetCallState();
  }, 8000);
}

function maybeSendCallLog(status) {
  if (!callState.isCaller || !callState.peer || callState.logSent) return;
  const duration = status === "ended" ? getCallDurationSeconds() : 0;
  const payload = buildCallLogPayload(status, "outgoing", duration, callState.mediaType);
  const tempId = createClientTempId();
  const target = callState.peer;
  if (activeFriend && normalizeName(activeFriend) === normalizeName(target)) {
    queuePendingMessage({ to: target, text: payload, clientTempId: tempId }, { queue: false });
  }
  socket.emit("private_message", { to: target, toType: "friend", text: payload, clientTempId: tempId });
  callState.logSent = true;
}

function applyVideoState() {
  if (callState.localStream) {
    callState.localStream.getVideoTracks().forEach((track) => {
      track.enabled = callState.videoEnabled;
    });
  }
  if (callLocalVideo) {
    const hasVideo = Boolean(callState.localStream && callState.localStream.getVideoTracks().length);
    callLocalVideo.classList.toggle("hidden", !callState.videoEnabled || !hasVideo);
  }
}

function setCallMinimized(value) {
  callState.minimized = Boolean(value);
  updateCallUi();
}

function updateCallUi() {
  if (!callModal) return;
  const setCallControlText = (btn, text) => {
    if (!btn) return;
    const label = btn.querySelector(".call-control-label");
    if (label) label.textContent = text;
    else btn.textContent = text;
    btn.setAttribute("aria-label", text);
  };
  const show = callState.status !== "idle" && !callState.minimized;
  callModal.classList.toggle("hidden", !show);
  callModal.setAttribute("aria-hidden", show ? "false" : "true");
  callModal.classList.toggle("video", callState.mediaType === "video");
  if (callPeerName) callPeerName.textContent = getCallPeerDisplayName(callState.peer);
  if (callAvatar) {
    const displayName = getCallPeerDisplayName(callState.peer);
    const trimmed = String(displayName || "").trim();
    callAvatar.textContent = trimmed ? trimmed.slice(0, 2).toUpperCase() : "?";
  }
  if (callMiniAvatar) {
    const displayName = getCallPeerDisplayName(callState.peer);
    const trimmed = String(displayName || "").trim();
    callMiniAvatar.textContent = trimmed ? trimmed.slice(0, 2).toUpperCase() : "?";
  }
  if (callBadge) {
    callBadge.textContent = callState.mediaType === "video" ? "VIDEO CALL" : "VOICE CALL";
  }
  if (callMinimizeBtn) {
    callMinimizeBtn.style.display = callState.status === "incoming" ? "none" : "inline-flex";
    callMinimizeBtn.disabled = callState.status === "idle";
  }

  const statusLabel = getCallStatusLabel();
  if (callStatusText) callStatusText.textContent = statusLabel;
  if (callMiniName) callMiniName.textContent = getCallPeerDisplayName(callState.peer);
  if (callMiniStatus) callMiniStatus.textContent = statusLabel;
  if (callMini) {
    callMini.classList.toggle("hidden", callState.status === "idle" || !callState.minimized);
  }

  if (callAcceptBtn) callAcceptBtn.style.display = callState.status === "incoming" ? "inline-flex" : "none";
  if (callRejectBtn) callRejectBtn.style.display = callState.status === "incoming" ? "inline-flex" : "none";
  setCallControlText(callAcceptBtn, "Answer");
  setCallControlText(callRejectBtn, "Decline");
  if (callHangupBtn) {
    const showHangup = ["outgoing", "ringing", "connecting", "reconnecting", "active"].includes(callState.status);
    callHangupBtn.style.display = showHangup ? "inline-flex" : "none";
    setCallControlText(
      callHangupBtn,
      ["outgoing", "ringing"].includes(callState.status) ? "Cancel" : "End call"
    );
  }

  const controlsEnabled = callState.status !== "idle";
  if (callMuteBtn) {
    callMuteBtn.disabled = !controlsEnabled;
    callMuteBtn.classList.toggle("muted", callState.muted);
    callMuteBtn.classList.toggle("active", callState.muted);
    callMuteBtn.dataset.icon = callState.muted ? "off" : "on";
    callMuteBtn.setAttribute("aria-pressed", callState.muted ? "true" : "false");
    callMuteBtn.title = callState.muted ? "Unmute" : "Mute";
    const label = callMuteBtn.querySelector("span");
    if (label) label.textContent = callState.muted ? "Unmute" : "Mute";
  }
  if (callSpeakerBtn) {
    callSpeakerBtn.disabled = !controlsEnabled;
    callSpeakerBtn.classList.toggle("active", callState.speakerOn);
    callSpeakerBtn.dataset.icon = callState.speakerOn ? "on" : "off";
    callSpeakerBtn.setAttribute("aria-pressed", callState.speakerOn ? "true" : "false");
    callSpeakerBtn.title = callState.speakerOn ? "Speaker" : "Speaker off";
    const label = callSpeakerBtn.querySelector("span");
    if (label) label.textContent = callState.speakerOn ? "Speaker" : "Speaker off";
  }
  if (callCameraBtn) {
    const showVideo = callState.mediaType === "video";
    const hasLocalVideo = Boolean(callState.localStream && callState.localStream.getVideoTracks().length);
    callCameraBtn.style.display = showVideo ? "inline-flex" : "none";
    callCameraBtn.disabled = !controlsEnabled || !showVideo || !hasLocalVideo;
    callCameraBtn.classList.toggle("active", callState.videoEnabled);
    callCameraBtn.setAttribute("aria-pressed", callState.videoEnabled ? "true" : "false");
    const label = callCameraBtn.querySelector("span");
    if (label) label.textContent = callState.videoEnabled ? "Camera" : "Camera off";
  }
  if (callFlipBtn) {
    const showVideo = callState.mediaType === "video";
    callFlipBtn.style.display = showVideo ? "inline-flex" : "none";
    const hasLocalVideo = Boolean(callState.localStream && callState.localStream.getVideoTracks().length);
    callFlipBtn.disabled = !controlsEnabled || !showVideo || !hasLocalVideo;
  }
  if (callState.status !== "active") {
    hideSpeakingIndicator("call");
  }
  updateCallTimer();
}

function resetCallState() {
  clearCallRingTimeout();
  clearOfferRetry();
  clearAnswerRetry();
  clearReconnectTimer();
  stopRemoteSpeakingMonitor();
  stopCallTimer();
  if (callState.pc) {
    callState.pc.onicecandidate = null;
    callState.pc.ontrack = null;
    callState.pc.onconnectionstatechange = null;
    callState.pc.close();
  }
  if (callState.localStream) {
    callState.localStream.getTracks().forEach((t) => t.stop());
  }
  callState.status = "idle";
  callState.peer = "";
  callState.isCaller = false;
  callState.pc = null;
  callState.localStream = null;
  callState.remoteStream = null;
  callState.pendingOffer = null;
  callState.pendingLocalOffer = null;
  callState.pendingLocalAnswer = null;
  callState.lastRemoteOfferSdp = "";
  callState.lastRemoteAnswerSdp = "";
  callState.pendingCandidates = [];
  callState.muted = false;
  callState.speakerOn = true;
  callState.inviteAcknowledged = false;
  callState.mediaType = "audio";
  callState.videoEnabled = true;
  callState.videoFacing = "user";
  callState.minimized = false;
  callState.logSent = false;
  callState.reconnectTimer = null;
  callState.ringTimeoutTimer = null;
  callState.offerRetryTimer = null;
  callState.answerRetryTimer = null;
  callState.offerRetryCount = 0;
  callState.answerRetryCount = 0;
  if (callRemoteAudio) {
    callRemoteAudio.srcObject = null;
    callRemoteAudio.muted = false;
    callRemoteAudio.volume = 1;
  }
  if (callRemoteVideo) {
    callRemoteVideo.srcObject = null;
    callRemoteVideo.classList.add("hidden");
  }
  if (callLocalVideo) {
    callLocalVideo.srcObject = null;
    callLocalVideo.classList.add("hidden");
  }
  updateCallUi();
}

function applyMuteState() {
  if (callState.localStream) {
    callState.localStream.getAudioTracks().forEach((track) => {
      track.enabled = !callState.muted;
    });
  }
}

function applySpeakerState() {
  if (callRemoteAudio) {
    callRemoteAudio.muted = !callState.speakerOn;
    callRemoteAudio.volume = callState.speakerOn ? 1 : 0;
  }
  if (callRemoteVideo) {
    callRemoteVideo.muted = true;
  }
}

function stopRemoteSpeakingMonitor() {
  if (remoteSpeakingState.rafId) {
    cancelAnimationFrame(remoteSpeakingState.rafId);
    remoteSpeakingState.rafId = 0;
  }
  if (remoteSpeakingState.source) {
    try { remoteSpeakingState.source.disconnect(); } catch (_) {}
  }
  if (remoteSpeakingState.analyser) {
    try { remoteSpeakingState.analyser.disconnect(); } catch (_) {}
  }
  if (remoteSpeakingState.context) {
    const ctx = remoteSpeakingState.context;
    remoteSpeakingState.context = null;
    Promise.resolve(ctx.close()).catch(() => {});
  }
  remoteSpeakingState.source = null;
  remoteSpeakingState.analyser = null;
  remoteSpeakingState.data = null;
  remoteSpeakingState.speakingFrames = 0;
  remoteSpeakingState.silentFrames = 0;
  remoteSpeakingState.speaking = false;
  hideSpeakingIndicator("call");
}

function startRemoteSpeakingMonitor(stream) {
  stopRemoteSpeakingMonitor();
  if (!(stream instanceof MediaStream)) return;
  if (!stream.getAudioTracks().length) return;
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (typeof AudioContextClass !== "function") return;

  let context = null;
  try {
    context = new AudioContextClass();
  } catch (_) {
    return;
  }
  if (!context) return;

  let analyser = null;
  let source = null;
  try {
    analyser = context.createAnalyser();
    analyser.fftSize = 512;
    analyser.smoothingTimeConstant = 0.86;
    source = context.createMediaStreamSource(stream);
    source.connect(analyser);
  } catch (_) {
    Promise.resolve(context.close()).catch(() => {});
    return;
  }

  remoteSpeakingState.context = context;
  remoteSpeakingState.analyser = analyser;
  remoteSpeakingState.source = source;
  remoteSpeakingState.data = new Uint8Array(analyser.frequencyBinCount);
  remoteSpeakingState.speakingFrames = 0;
  remoteSpeakingState.silentFrames = 0;
  remoteSpeakingState.speaking = false;

  Promise.resolve(context.resume()).catch(() => {});

  const detectSpeaking = () => {
    if (!remoteSpeakingState.analyser || !remoteSpeakingState.data) {
      stopRemoteSpeakingMonitor();
      return;
    }

    if (callState.status === "idle" || !callState.remoteStream || !callState.remoteStream.getAudioTracks().length) {
      stopRemoteSpeakingMonitor();
      return;
    }

    remoteSpeakingState.analyser.getByteFrequencyData(remoteSpeakingState.data);
    let total = 0;
    let peak = 0;
    for (const value of remoteSpeakingState.data) {
      total += value;
      if (value > peak) peak = value;
    }
    const average = remoteSpeakingState.data.length ? total / remoteSpeakingState.data.length : 0;
    const speakingLevel = Math.max(average, peak * 0.72);
    const isSpeakingFrame = speakingLevel > 20;

    if (isSpeakingFrame) {
      remoteSpeakingState.speakingFrames += 1;
      remoteSpeakingState.silentFrames = 0;
    } else {
      remoteSpeakingState.silentFrames += 1;
      remoteSpeakingState.speakingFrames = 0;
    }

    if (!remoteSpeakingState.speaking && remoteSpeakingState.speakingFrames >= 2 && callState.status === "active") {
      remoteSpeakingState.speaking = true;
      showSpeakingIndicator(callState.peer, { source: "call" });
    } else if (remoteSpeakingState.speaking && (remoteSpeakingState.silentFrames >= 8 || callState.status !== "active")) {
      remoteSpeakingState.speaking = false;
      hideSpeakingIndicator("call");
    }

    remoteSpeakingState.rafId = requestAnimationFrame(detectSpeaking);
  };

  remoteSpeakingState.rafId = requestAnimationFrame(detectSpeaking);
}

function toggleMute() {
  callState.muted = !callState.muted;
  applyMuteState();
  updateCallUi();
}

function toggleSpeaker() {
  callState.speakerOn = !callState.speakerOn;
  applySpeakerState();
  updateCallUi();
}

function toggleCamera() {
  if (callState.mediaType !== "video") return;
  if (!callState.localStream) return;
  callState.videoEnabled = !callState.videoEnabled;
  applyVideoState();
  updateCallUi();
}

async function switchCamera() {
  if (callState.mediaType !== "video") return;
  if (!navigator.mediaDevices?.getUserMedia) return;
  const nextFacing = callState.videoFacing === "user" ? "environment" : "user";
  try {
    const newStream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: nextFacing },
    });
    const newTrack = newStream.getVideoTracks()[0];
    if (!newTrack) return;
    callState.videoFacing = nextFacing;
    newTrack.enabled = callState.videoEnabled;

    if (!callState.localStream) {
      callState.localStream = new MediaStream();
    }

    const oldTracks = callState.localStream.getVideoTracks();
    oldTracks.forEach((track) => {
      callState.localStream.removeTrack(track);
      track.stop();
    });
    callState.localStream.addTrack(newTrack);

    if (callState.pc) {
      const sender = callState.pc.getSenders().find((s) => s.track && s.track.kind === "video");
      if (sender) {
        await sender.replaceTrack(newTrack);
      } else {
        callState.pc.addTrack(newTrack, callState.localStream);
      }
    }

    if (callLocalVideo) {
      callLocalVideo.srcObject = callState.localStream;
      callLocalVideo.classList.toggle("hidden", !callState.videoEnabled);
      callLocalVideo.play().catch(() => {});
    }
  } catch (err) {
    console.error(err);
    showToast("Unable to switch camera.", "error");
  }
}

function createCallPeerConnection() {
  const pc = new RTCPeerConnection({ iceServers: callIceServers });

  pc.onicecandidate = (event) => {
    if (!event.candidate || !callState.peer) return;
    socket.emit("call_signal", {
      to: callState.peer,
      type: "ice",
      candidate: event.candidate,
    });
  };

  pc.ontrack = (event) => {
    if (!callState.remoteStream) {
      callState.remoteStream = new MediaStream();
    }
    callState.remoteStream.addTrack(event.track);
    if (callRemoteAudio) {
      callRemoteAudio.srcObject = callState.remoteStream;
      callRemoteAudio.play().catch(() => {});
      applySpeakerState();
    }
    if (callRemoteVideo) {
      callRemoteVideo.srcObject = callState.remoteStream;
      if (callState.remoteStream.getVideoTracks().length) {
        callRemoteVideo.classList.remove("hidden");
        callRemoteVideo.play().catch(() => {});
      }
    }
    startRemoteSpeakingMonitor(callState.remoteStream);
  };

  pc.onconnectionstatechange = () => {
    if (pc.connectionState === "connected") {
      callState.status = "active";
      clearCallRingTimeout();
      clearOfferRetry();
      clearAnswerRetry();
      clearReconnectTimer();
      startCallTimer();
      updateCallUi();
      return;
    }
    if (pc.connectionState === "disconnected") {
      callState.status = "reconnecting";
      updateCallUi();
      scheduleReconnectTimeout();
      return;
    }
    if (["failed", "closed"].includes(pc.connectionState)) {
      showToast("Call disconnected.", "info");
      maybeSendCallLog("ended");
      resetCallState();
    }
  };

  return pc;
}

function flushPendingCandidates() {
  if (!callState.pc || !callState.pc.remoteDescription) return;
  const pending = callState.pendingCandidates.splice(0, callState.pendingCandidates.length);
  pending.forEach((candidate) => {
    callState.pc.addIceCandidate(candidate).catch(() => {});
  });
}

async function applyRemoteOffer(offer) {
  if (!callState.pc || !offer) return;
  const offerSdpText = typeof offer?.sdp === "string" ? offer.sdp : "";
  if (offerSdpText) callState.lastRemoteOfferSdp = offerSdpText;
  await callState.pc.setRemoteDescription(new RTCSessionDescription(offer));
  const answer = await callState.pc.createAnswer();
  await callState.pc.setLocalDescription(answer);
  startAnswerRetry(callState.pc.localDescription);
  flushPendingCandidates();
}

async function startCall(mediaType = "audio") {
  if (!socketAvailable) {
    showToast("Realtime connection not available.", "error");
    return;
  }
  if (!activeFriend) {
    showToast("Choose a friend first.", "error");
    return;
  }
  const activeEntry = getActiveChatEntry();
  if (normalizeChatKind(activeEntry?.kind || activeChatKind) === "group") {
    showToast("Group calls are coming soon.", "info");
    return;
  }
  const safety = getFriendSafety(activeFriend, "friend");
  if (safety.blockedByMe) {
    showToast("Unblock this contact to start calls.", "error");
    return;
  }
  if (safety.blockedYou) {
    showToast("This user has blocked you.", "error");
    return;
  }
  if (!navigator.mediaDevices?.getUserMedia) {
    showToast("Calling not supported in this browser.", "error");
    return;
  }
  if (!window.RTCPeerConnection) {
    showToast("Calling not supported in this browser.", "error");
    return;
  }
  if (callState.status !== "idle") {
    showToast("You're already in a call.", "error");
    return;
  }

  await ensureCallIceServers();

  callState.peer = activeFriend;
  callState.isCaller = true;
  callState.status = "outgoing";
  callState.mediaType = mediaType === "video" ? "video" : "audio";
  callState.videoEnabled = callState.mediaType === "video";
  callState.videoFacing = "user";
  callState.inviteAcknowledged = false;
  callState.minimized = false;
  callState.logSent = false;
  callState.pendingLocalOffer = null;
  callState.pendingLocalAnswer = null;
  clearOfferRetry();
  clearAnswerRetry();
  stopCallTimer();
  updateCallUi();

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: true,
      video: callState.mediaType === "video" ? { facingMode: callState.videoFacing } : false,
    });
    callState.localStream = stream;
    callState.pc = createCallPeerConnection();
    stream.getTracks().forEach((track) => callState.pc.addTrack(track, stream));
    applyMuteState();
    applyVideoState();
    if (callLocalVideo) {
      callLocalVideo.srcObject = stream;
      if (stream.getVideoTracks().length) {
        callLocalVideo.classList.remove("hidden");
        callLocalVideo.play().catch(() => {});
      }
    }

    const offer = await callState.pc.createOffer({
      offerToReceiveAudio: true,
      offerToReceiveVideo: callState.mediaType === "video",
    });
    await callState.pc.setLocalDescription(offer);
    startOutgoingCallTimeout();
    startOfferRetry(callState.pc.localDescription);
  } catch (err) {
    console.error(err);
    showToast("Camera or microphone permission blocked.", "error");
    if (callState.peer) socket.emit("call_cancel", { to: callState.peer });
    resetCallState();
  }
}

function startVoiceCall() {
  startCall("audio");
}

function startVideoCall() {
  startCall("video");
}

async function acceptIncomingCall() {
  if (callState.status !== "incoming") return;
  if (!navigator.mediaDevices?.getUserMedia) {
    showToast("Calling not supported in this browser.", "error");
    return;
  }
  if (!window.RTCPeerConnection) {
    showToast("Calling not supported in this browser.", "error");
    return;
  }

  await ensureCallIceServers();

  callState.status = "connecting";
  callState.inviteAcknowledged = true;
  clearCallRingTimeout();
  clearOfferRetry();
  clearAnswerRetry();
  updateCallUi();
  socket.emit("call_answer", { to: callState.peer });

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: true,
      video: callState.mediaType === "video" ? { facingMode: callState.videoFacing } : false,
    });
    callState.localStream = stream;
    callState.pc = createCallPeerConnection();
    stream.getTracks().forEach((track) => callState.pc.addTrack(track, stream));
    applyMuteState();
    applyVideoState();
    if (callLocalVideo) {
      callLocalVideo.srcObject = stream;
      if (stream.getVideoTracks().length) {
        callLocalVideo.classList.remove("hidden");
        callLocalVideo.play().catch(() => {});
      }
    }
    if (callState.pendingOffer) {
      const offer = callState.pendingOffer;
      callState.pendingOffer = null;
      await applyRemoteOffer(offer);
    }
  } catch (err) {
    console.error(err);
    showToast("Camera or microphone permission blocked.", "error");
    socket.emit("call_reject", { to: callState.peer });
    resetCallState();
  }
}

function rejectIncomingCall() {
  if (callState.status !== "incoming") return;
  if (callState.peer) socket.emit("call_reject", { to: callState.peer });
  resetCallState();
}

function hangupCall() {
  if (!callState.peer) {
    resetCallState();
    return;
  }
  const cancelling = ["outgoing", "ringing"].includes(callState.status);
  if (cancelling) {
    socket.emit("call_cancel", { to: callState.peer });
  } else {
    socket.emit("call_end", { to: callState.peer });
  }
  maybeSendCallLog(cancelling ? "cancelled" : "ended");
  resetCallState();
}

async function handleCallSignal(payload) {
  const from = String(payload?.from || "").trim();
  if (!from) return;

  if (!INCOMING_CALLS_ENABLED && callState.status === "idle") {
    socket.emit("call_reject", { to: from });
    return;
  }

  if (callState.status === "idle") {
    callState.peer = from;
    callState.isCaller = false;
    callState.status = "incoming";
    updateCallUi();
  }

  if (normalizeName(from) !== normalizeName(callState.peer)) return;

  if (payload?.type === "offer") {
    if (callState.status === "active") return;
    const incomingOfferSdp = typeof payload?.sdp?.sdp === "string" ? payload.sdp.sdp : "";
    if (
      incomingOfferSdp &&
      incomingOfferSdp === callState.lastRemoteOfferSdp &&
      callState.pendingLocalAnswer
    ) {
      startAnswerRetry(callState.pendingLocalAnswer);
      return;
    }
    callState.pendingOffer = payload.sdp;
    if (callState.pc && callState.status !== "outgoing") {
      const offer = callState.pendingOffer;
      callState.pendingOffer = null;
      await applyRemoteOffer(offer);
    }
    return;
  }

  if (payload?.type === "answer") {
    if (!callState.pc) return;
    const incomingAnswerSdp = typeof payload?.sdp?.sdp === "string" ? payload.sdp.sdp : "";
    if (incomingAnswerSdp && incomingAnswerSdp === callState.lastRemoteAnswerSdp) {
      clearCallRingTimeout();
      clearOfferRetry();
      return;
    }
    await callState.pc.setRemoteDescription(new RTCSessionDescription(payload.sdp));
    if (incomingAnswerSdp) callState.lastRemoteAnswerSdp = incomingAnswerSdp;
    clearCallRingTimeout();
    clearOfferRetry();
    callState.status = "connecting";
    updateCallUi();
    flushPendingCandidates();
    return;
  }

  if (payload?.type === "ice" && payload.candidate) {
    if (callState.pc && callState.pc.remoteDescription) {
      callState.pc.addIceCandidate(payload.candidate).catch(() => {});
    } else {
      callState.pendingCandidates.push(payload.candidate);
    }
  }
}

function createClientTempId() {
  return `tmp-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

function pendingRetryDelay(attempts) {
  const safeAttempts = Math.max(1, Number(attempts) || 1);
  const backoff = PENDING_RETRY_BASE_MS * Math.pow(1.45, safeAttempts - 1);
  return Math.min(PENDING_RETRY_MAX_MS, Math.round(backoff));
}

function ensurePendingQueueEntry(payload, tempId) {
  if (!payload || !payload.to || !payload.text || !tempId) return null;
  const nextPayload = { ...payload, clientTempId: tempId };
  const existing = pendingQueueByTempId.get(tempId);
  if (existing) {
    existing.payload = nextPayload;
    schedulePersistPendingState();
    return existing;
  }

  const entry = {
    tempId,
    payload: nextPayload,
    attempts: 0,
    lastAttemptAt: 0,
    nextAttemptAt: 0,
  };
  pendingQueue.push(entry);
  pendingQueueByTempId.set(tempId, entry);
  schedulePersistPendingState();
  return entry;
}

function rerenderPendingMessageRow(tempId) {
  if (!tempId || !messagesEl) return;
  const message = pendingByTempId.get(tempId);
  if (!message) return;
  const row = messagesEl.querySelector(`[data-client-temp-id="${tempId}"]`);
  if (!row) return;
  const replacement = buildMessageElement(message, true);
  row.replaceWith(replacement);
}

function markPendingMessageFailed(tempId, options = {}) {
  if (!tempId) return false;
  const message = pendingByTempId.get(tempId);
  if (!message) {
    // Orphaned queue entries can happen after reloads or reconciliation edge-cases.
    // Drop them so they don't get stuck retrying forever.
    removePendingFromQueue(tempId);
    renderNetworkState();
    return false;
  }
  message.pending = false;
  message.failed = true;
  message.failedAt = new Date().toISOString();
  removePendingFromQueue(tempId);
  schedulePersistPendingState();
  rerenderPendingMessageRow(tempId);
  applyMessageSearch();
  renderNetworkState();
  if (options.toast !== false) {
    showToast("Message failed to send. Tap Retry.", "error");
  }
  return true;
}

function retryFailedMessage(tempId, options = {}) {
  if (!tempId) return;
  const message = pendingByTempId.get(tempId);
  if (!message) return;

  message.failed = false;
  message.failedAt = "";
  message.pending = true;

  const payload = {
    to: message.to,
    toType: normalizeChatKind(message.toType || message.kind || "friend"),
    text: message.text,
    clientTempId: tempId,
  };
  if (message.replyTo) payload.replyTo = message.replyTo;
  if (message.attachment) payload.attachment = message.attachment;

  const entry = ensurePendingQueueEntry(payload, tempId);
  if (!entry) return;
  entry.attempts = 0;
  entry.lastAttemptAt = 0;
  entry.nextAttemptAt = 0;
  schedulePersistPendingState();

  rerenderPendingMessageRow(tempId);
  applyMessageSearch();
  if (socketAvailable && socket.connected) {
    sendQueuedMessage(entry);
    if (options.toast !== false) {
      showToast("Retrying message...", "info");
    }
  } else if (options.toast !== false) {
    showToast("Message re-queued. We'll send when online.", "info");
  }
  renderNetworkState();
}

function sendQueuedMessage(entry) {
  if (!entry || !socketAvailable || !socket.connected) return false;
  const target = entry.payload?.to || "";
  const targetKind = normalizeChatKind(entry.payload?.toType || "friend");
  if (targetKind === "friend") {
    const safety = getFriendSafety(target, "friend");
    if (safety.blocked) {
      markPendingMessageFailed(entry.tempId, { toast: false });
      return false;
    }
  }
  const pendingMessage = pendingByTempId.get(entry.tempId);
  if (pendingMessage) {
    pendingMessage.failed = false;
    pendingMessage.pending = true;
  }
  socket.emit("private_message", entry.payload);
  entry.attempts += 1;
  entry.lastAttemptAt = Date.now();
  entry.nextAttemptAt = entry.lastAttemptAt + pendingRetryDelay(entry.attempts);
  schedulePersistPendingState();
  return true;
}

function removePendingFromQueue(tempId) {
  if (!tempId) return;
  const existing = pendingQueueByTempId.get(tempId);
  if (!existing) return;
  pendingQueueByTempId.delete(tempId);
  const idx = pendingQueue.indexOf(existing);
  if (idx >= 0) pendingQueue.splice(idx, 1);
  schedulePersistPendingState();
}

function queuePendingMessage(payload, options = {}) {
  if (!payload || !payload.to || !payload.text) return;
  const payloadType = normalizeChatKind(payload.toType || "friend");
  const shouldQueue = options.queue !== false;
  const shouldUpdateFriends = options.updateFriends !== false;
  const tempId = payload.clientTempId || createClientTempId();
  const timestamp = new Date().toISOString();
  const labsParsed = extractLabsMetaFromText(payload.text);
  const sanitizedText = labsParsed.text;
  const targetIsActiveThread = Boolean(
    activeFriend && isSameChatTarget(payload.to, payloadType, activeFriend, activeChatKind)
  );
  const wasAtLatest = targetIsActiveThread ? !hasNewerMessages() : false;

  const message = {
    id: tempId,
    clientTempId: tempId,
    from: me || "You",
    to: payload.to,
    toType: payloadType,
    kind: payloadType,
    groupId: payloadType === "group" ? payload.to : "",
    text: sanitizedText,
    timestamp,
    deliveredAt: null,
    seenAt: null,
    pending: true,
    failed: false,
    novynMeta: labsParsed.meta || {},
    replyTo: payload.replyTo || null,
    attachment: normalizeAttachmentPayload(payload.attachment, sanitizedText),
    reactions: {},
  };

  if (targetIsActiveThread) {
    conversationMessages.push(message);
  }
  if (shouldUpdateFriends) {
    friends = friends.map((f) =>
      isSameChatTarget(f.username, f.kind || "friend", payload.to, payloadType)
        ? { ...f, lastMessage: sanitizedText, lastFrom: me, lastTimestamp: timestamp }
        : f
    );
    renderFriends();
  }
  pendingByTempId.set(tempId, message);
  if (shouldQueue) ensurePendingQueueEntry(payload, tempId);
  schedulePersistPendingState();
  renderNetworkState();

  if (targetIsActiveThread && wasAtLatest) {
    messageWindowEnd = conversationMessages.length;
    appendMessage(message);
    const currentWindowSize = getCurrentMessageWindowSize();
    if (messagesEl && messagesEl.querySelectorAll("article.message").length > currentWindowSize) {
      messageWindowStart = Math.max(0, messageWindowEnd - currentWindowSize);
      renderMessageWindow({ maxVisible: currentWindowSize });
    }
  }
  return tempId;
}

function updatePendingMessageText(tempId, text) {
  if (!tempId) return;
  const msg = pendingByTempId.get(tempId);
  if (!msg) return;
  msg.text = text;
  const row = messagesEl ? messagesEl.querySelector(`[data-client-temp-id="${tempId}"]`) : null;
  if (row) {
    const newRow = buildMessageElement(msg, true);
    row.replaceWith(newRow);
  }
  schedulePersistPendingState();
  applyMessageSearch();
  if (normalizeName(msg.from) === normalizeName(me)) {
    pinConversationToBottom();
  }
}

function updatePendingMessageAttachment(tempId, attachment, fallbackText = "") {
  if (!tempId) return;
  const msg = pendingByTempId.get(tempId);
  if (!msg) return;
  const normalizedAttachment = normalizeAttachmentPayload(attachment, fallbackText || msg.text || "");
  if (!normalizedAttachment) return;
  msg.attachment = normalizedAttachment;
  msg.text = normalizedAttachment.url || fallbackText || msg.text || "";
  const row = messagesEl ? messagesEl.querySelector(`[data-client-temp-id="${tempId}"]`) : null;
  if (row) {
    const newRow = buildMessageElement(msg, true);
    row.replaceWith(newRow);
  }
  schedulePersistPendingState();
  applyMessageSearch();
  if (normalizeName(msg.from) === normalizeName(me)) {
    pinConversationToBottom();
  }
}

function removePendingMessage(tempId) {
  if (!tempId) return;
  pendingByTempId.delete(tempId);
  removePendingFromQueue(tempId);
  const idx = conversationMessages.findIndex((m) => m.clientTempId === tempId || m.id === tempId);
  if (idx >= 0) conversationMessages.splice(idx, 1);
  const row = messagesEl ? messagesEl.querySelector(`[data-client-temp-id="${tempId}"]`) : null;
  if (row) row.remove();
  messageWindowEnd = Math.min(messageWindowEnd, conversationMessages.length);
  schedulePersistPendingState();
  applyMessageSearch();
}

function flushPendingQueue(force = false) {
  if (!socketAvailable || !socket.connected) {
    renderNetworkState();
    return;
  }
  if (!pendingQueue.length) {
    renderNetworkState();
    return;
  }
  const now = Date.now();
  const queueSnapshot = pendingQueue.slice();
  let failedAny = false;
  let blockedAny = false;
  queueSnapshot.forEach((item) => {
    if (item.attempts >= PENDING_RETRY_MAX_ATTEMPTS) {
      if (markPendingMessageFailed(item.tempId, { toast: false })) {
        failedAny = true;
      }
      return;
    }
    if (!force && item.nextAttemptAt > now) return;
    const sent = sendQueuedMessage(item);
    if (!sent) {
      const pendingMessage = pendingByTempId.get(item.tempId);
      if (pendingMessage?.failed) blockedAny = true;
    }
  });
  if (failedAny) {
    showToast("Some messages failed to send. Tap Retry.", "error");
  }
  if (blockedAny) {
    showToast("Some queued messages are blocked by safety settings.", "info");
  }
  renderNetworkState();
}

function sendMessagePayload(payload, options = {}) {
  if (!payload || !payload.to) return;
  const payloadType = normalizeChatKind(payload.toType || activeChatKind || "friend");
  const resolvedTo = resolveOutgoingTarget(payload.to, payloadType);
  if (!resolvedTo) return;
  if (payloadType === "friend") {
    const safety = getFriendSafety(resolvedTo, "friend");
    if (safety.blocked) {
      if (options.toast !== false) {
        showToast(safety.blockedByMe ? "Unblock this contact to send messages." : "This user has blocked you.", "error");
      }
      return;
    }
  }
  const validatedText = validateOutgoingMessageText(payload.text);
  if (validatedText === null || !validatedText) return;
  const outgoingPayload = { ...payload, to: resolvedTo, toType: payloadType, text: validatedText };
  const normalizedAttachment = normalizeAttachmentPayload(payload.attachment, validatedText);
  if (normalizedAttachment) {
    outgoingPayload.attachment = normalizedAttachment;
  } else if ("attachment" in outgoingPayload) {
    delete outgoingPayload.attachment;
  }
  const tempId = outgoingPayload.clientTempId || createClientTempId();
  let queuedEntry = pendingQueueByTempId.get(tempId);

  if (!socketAvailable || !socket.connected) {
    if (options.optimistic === false) {
      if (pendingByTempId.has(tempId)) {
        queuedEntry = ensurePendingQueueEntry(outgoingPayload, tempId);
        const pendingMessage = pendingByTempId.get(tempId);
        if (pendingMessage) {
          pendingMessage.pending = true;
          pendingMessage.failed = false;
          pendingMessage.text = validatedText;
          pendingMessage.attachment = normalizedAttachment;
        }
        rerenderPendingMessageRow(tempId);
        applyMessageSearch();
      } else {
        queuePendingMessage({ ...outgoingPayload, clientTempId: tempId }, { queue: true });
      }
      renderNetworkState();
      showToast("Message queued. We'll send when you're back online.", "info");
      return tempId;
    }
    queuePendingMessage({ ...outgoingPayload, clientTempId: tempId }, { queue: true });
    showToast("Message queued. We'll send when you're back online.", "info");
    return tempId;
  }

  if (options.optimistic !== false) {
    queuePendingMessage({ ...outgoingPayload, clientTempId: tempId }, { queue: true });
    queuedEntry = pendingQueueByTempId.get(tempId);
  } else {
    queuedEntry = ensurePendingQueueEntry(outgoingPayload, tempId);
    renderNetworkState();
  }
  if (queuedEntry) {
    sendQueuedMessage(queuedEntry);
    renderNetworkState();
  }
  return tempId;
}

function sendActiveMessage() {
  const text = messageInput.value.trim();
  if (!activeFriend) { showToast("Choose a friend first.", "error"); return; }
  const chatKey = getLabsChatKey(activeFriend, activeChatKind);
  if (handleNovynLabsCommand(text, chatKey)) {
    messageInput.value = "";
    messageInput.dispatchEvent(new Event("input", { bubbles: true }));
    removeMessageDraft(activeFriend);
    if (sendButton) sendButton.classList.remove("ready");
    clearReply();
    keepComposerFocused();
    return;
  }
  if (normalizeChatKind(activeChatKind) === "friend") {
    const safety = getFriendSafety(activeFriend, "friend");
    if (safety.blockedByMe) {
      showToast("Unblock this contact to send messages.", "error");
      return;
    }
    if (safety.blockedYou) {
      showToast("This user has blocked you.", "error");
      return;
    }
  }
  if (!text) return;
  closeScheduleMenu();

  if (hasNewerMessages()) {
    showLatestMessages();
  }
  stopLocalTyping();
  const branch = getLabsBranchForChat(chatKey);
  const intent = getLabsDefaultIntentForChat(chatKey);
  const trustMode = getLabsTrustModeForChat(chatKey);
  const sensitive = trustMode
    && /\b(?:password|passcode|otp|token|secret|upi|pin|cvv)\b/i.test(text);
  const outgoingText = injectLabsMetaIntoText(text, { branch, intent, sensitive });

  const activeEntry = getActiveChatEntry();
  const presenceMode = resolveFriendPresenceMode(activeEntry);
  const smartDelay = Boolean(
    novynLabsState.contextAwareDelivery
    && normalizeChatKind(activeChatKind) === "friend"
    && intent !== "urgent"
    && (presenceMode === "away" || presenceMode === "offline")
  );
  if (smartDelay && socketAvailable && socket.connected) {
    const resolvedTo = resolveOutgoingTarget(activeFriend, activeChatKind);
    if (!resolvedTo) {
      showToast("Unable to resolve this chat.", "error");
      return;
    }
    const sendAt = new Date(Date.now() + 2 * 60 * 1000).toISOString();
    const scheduledPayload = {
      to: resolvedTo,
      toType: normalizeChatKind(activeChatKind),
      text: outgoingText,
      sendAt,
    };
    if (replyTo) scheduledPayload.replyTo = replyTo;
    socket.emit("schedule_message", scheduledPayload);
    messageInput.value = "";
    messageInput.dispatchEvent(new Event("input", { bubbles: true }));
    removeMessageDraft(activeFriend);
    if (sendButton) sendButton.classList.remove("ready");
    clearReply();
    showToast("Recipient looks unavailable, so this was smart-scheduled (+2m).", "info");
    scrollToBottom(true);
    scrollState.pinnedToBottom = true;
    keepComposerFocused();
    updateLabsLastViewedForChat(chatKey);
    return;
  }

  const payload = { to: activeFriend, toType: activeChatKind, text: outgoingText };
  if (replyTo) payload.replyTo = replyTo;
  const sentTempId = sendMessagePayload(payload);
  if (!sentTempId) return;
  messageInput.value = "";
  messageInput.dispatchEvent(new Event("input", { bubbles: true }));
  removeMessageDraft(activeFriend);
  if (sendButton) sendButton.classList.remove("ready");
  clearReply();

  // Keep scroll pinned to bottom after sending
  scrollToBottom(true);
  scrollState.pinnedToBottom = true;
  keepComposerFocused();
  updateLabsLastViewedForChat(chatKey);
}

function requestScheduledMessagesForActiveChat() {
  if (!socketAvailable || !activeFriend) {
    renderScheduledPanel();
    return;
  }
  const payloadType = normalizeChatKind(activeChatKind);
  const resolvedTo = resolveOutgoingTarget(activeFriend, payloadType);
  if (!resolvedTo) return;
  socket.emit("list_scheduled_messages", {
    to: resolvedTo,
    toType: payloadType,
  });
}

function formatScheduledLocal(isoText) {
  const date = new Date(isoText || "");
  if (Number.isNaN(date.getTime())) return "Unknown time";
  return date.toLocaleString([], {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

function buildDefaultScheduleDateParts(baseDate = null) {
  const date = baseDate instanceof Date && !Number.isNaN(baseDate.getTime())
    ? new Date(baseDate.getTime())
    : new Date(Date.now() + 15 * 60 * 1000);
  date.setSeconds(0, 0);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const hour = String(date.getHours()).padStart(2, "0");
  const minute = String(date.getMinutes()).padStart(2, "0");
  return {
    dateValue: `${year}-${month}-${day}`,
    timeValue: `${hour}:${minute}`,
  };
}

function parseScheduleInput(rawValue) {
  const raw = String(rawValue || "").trim();
  if (!raw) return null;
  if (/^\d+$/.test(raw)) {
    const minutes = Number(raw);
    if (!Number.isFinite(minutes) || minutes <= 0) return null;
    return new Date(Date.now() + minutes * 60 * 1000);
  }
  const normalized = raw.replace("T", " ");
  if (/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}$/.test(normalized)) {
    const [datePart, timePart] = normalized.split(/\s+/);
    const candidate = new Date(`${datePart}T${timePart}:00`);
    if (!Number.isNaN(candidate.getTime())) return candidate;
  }
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed;
}

function updateSchedulePreview(date) {
  if (!schedulePreviewText) return;
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    schedulePreviewText.textContent = "Pick a date and time";
    return;
  }
  schedulePreviewText.textContent = `Will send ${formatScheduledLocal(date.toISOString())}`;
}

function readScheduleDateFromInputs() {
  const datePart = String(scheduleDateInput?.value || "").trim();
  const timePart = String(scheduleTimeInput?.value || "").trim() || "09:00";
  if (!datePart) return null;
  return parseScheduleInput(`${datePart} ${timePart}`);
}

function setScheduleInputFromDate(date) {
  const nextParts = buildDefaultScheduleDateParts(date);
  if (scheduleDateInput) scheduleDateInput.value = nextParts.dateValue;
  if (scheduleTimeInput) scheduleTimeInput.value = nextParts.timeValue;
  updateSchedulePreview(readScheduleDateFromInputs());
}

function setScheduledPanelExpanded(nextValue) {
  const expanded = Boolean(nextValue);
  scheduledPanelExpanded = expanded;
  if (!scheduledPanel) return;
  scheduledPanel.classList.toggle("collapsed", !expanded);
  if (scheduledPanelToggleBtn) {
    scheduledPanelToggleBtn.setAttribute("aria-expanded", expanded ? "true" : "false");
  }
}

function isScheduleMenuOpen() {
  return Boolean(scheduleMenu && !scheduleMenu.classList.contains("hidden"));
}

function closeScheduleMenu() {
  if (!scheduleMenu) return;
  scheduleMenu.classList.add("hidden");
  if (scheduleBtn) scheduleBtn.setAttribute("aria-expanded", "false");
}

function openScheduleMenu() {
  if (!scheduleMenu) return;
  if (!activeFriend) {
    showToast("Choose a chat first.", "error");
    return;
  }
  requestScheduledMessagesForActiveChat();
  scheduleMenu.classList.remove("hidden");
  if (scheduleBtn) scheduleBtn.setAttribute("aria-expanded", "true");
  if (scheduleDateInput) {
    setScheduleInputFromDate();
    scheduleDateInput.focus();
  }
}

function renderScheduledPanel() {
  if (!scheduledPanel || !scheduledList || !scheduledEmpty) return;
  if (!activeFriend) {
    scheduledPanel.classList.add("hidden");
    if (scheduledPanelTitle) scheduledPanelTitle.textContent = "Scheduled messages";
    scheduledList.innerHTML = "";
    scheduledEmpty.textContent = "No scheduled messages";
    setScheduledPanelExpanded(false);
    return;
  }
  const messages = getScheduledMessagesForChat(activeFriend, activeChatKind);
  scheduledList.innerHTML = "";
  if (!messages.length) {
    scheduledPanel.classList.add("hidden");
    if (scheduledPanelTitle) scheduledPanelTitle.textContent = "Scheduled messages";
    scheduledEmpty.textContent = "No scheduled messages";
    setScheduledPanelExpanded(false);
    return;
  }

  scheduledPanel.classList.remove("hidden");
  if (scheduledPanelTitle) {
    scheduledPanelTitle.textContent = messages.length === 1
      ? "1 scheduled message"
      : `${messages.length} scheduled messages`;
  }
  setScheduledPanelExpanded(scheduledPanelExpanded);
  scheduledEmpty.textContent = "";
  messages.forEach((entry) => {
    const row = document.createElement("div");
    row.className = "scheduled-item";
    row.dataset.id = String(entry?.id || "");

    const main = document.createElement("div");
    main.className = "scheduled-item-main";

    const meta = document.createElement("div");
    meta.className = "scheduled-item-meta";
    meta.textContent = `Sends ${formatScheduledLocal(entry?.sendAt)}`;

    const text = document.createElement("div");
    text.className = "scheduled-item-text";
    const body = String(entry?.text || "").trim();
    text.textContent = body.length > 120 ? `${body.slice(0, 117)}...` : body;
    text.title = body;

    const cancelBtn = document.createElement("button");
    cancelBtn.type = "button";
    cancelBtn.className = "scheduled-item-cancel";
    cancelBtn.textContent = "Cancel";
    cancelBtn.addEventListener("click", () => {
      const id = String(entry?.id || "").trim();
      if (!id) return;
      socket.emit("cancel_scheduled_message", { id });
    });

    main.append(meta, text);
    row.append(main, cancelBtn);
    scheduledList.appendChild(row);
  });
}

function scheduleActiveMessage(scheduleDate) {
  if (!activeFriend) {
    showToast("Choose a chat first.", "error");
    return false;
  }
  const text = String(messageInput?.value || "").trim();
  if (!text) {
    showToast("Type a message to schedule.", "info");
    return false;
  }
  if (normalizeChatKind(activeChatKind) === "friend") {
    const safety = getFriendSafety(activeFriend, "friend");
    if (safety.blockedByMe || safety.blockedYou) {
      showToast("Scheduling is unavailable while blocked.", "error");
      return false;
    }
  }
  if (!(scheduleDate instanceof Date) || Number.isNaN(scheduleDate.getTime())) {
    showToast("Invalid date/time format.", "error");
    return false;
  }
  if (scheduleDate.getTime() - Date.now() < 30 * 1000) {
    showToast("Choose a time at least 30 seconds from now.", "error");
    return false;
  }
  const payload = {
    to: resolveOutgoingTarget(activeFriend, activeChatKind),
    toType: normalizeChatKind(activeChatKind),
    text,
    sendAt: scheduleDate.toISOString(),
  };
  if (!payload.to) {
    showToast("Unable to resolve this chat.", "error");
    return false;
  }
  if (replyTo) payload.replyTo = replyTo;
  socket.emit("schedule_message", payload);
  messageInput.value = "";
  messageInput.dispatchEvent(new Event("input", { bubbles: true }));
  removeMessageDraft(activeFriend);
  if (sendButton) sendButton.classList.remove("ready");
  clearReply();
  closeScheduleMenu();
  showToast("Message scheduled.", "success");
  return true;
}

messageForm.addEventListener("submit", (e) => {
  e.preventDefault();
  sendActiveMessage();
});
if (scheduleBtn) {
  scheduleBtn.addEventListener("click", (event) => {
    event.stopPropagation();
    if (isScheduleMenuOpen()) {
      closeScheduleMenu();
      return;
    }
    openScheduleMenu();
  });
}
if (scheduleMenuCloseBtn) {
  scheduleMenuCloseBtn.addEventListener("click", closeScheduleMenu);
}
if (scheduleMenuCancelBtn) {
  scheduleMenuCancelBtn.addEventListener("click", closeScheduleMenu);
}
if (scheduleMenuConfirmBtn) {
  scheduleMenuConfirmBtn.addEventListener("click", () => {
    const scheduleDate = readScheduleDateFromInputs();
    if (!scheduleDate) {
      showToast("Choose a valid schedule time.", "error");
      return;
    }
    scheduleActiveMessage(scheduleDate);
  });
}
if (scheduleDateInput) {
  scheduleDateInput.addEventListener("input", () => {
    updateSchedulePreview(readScheduleDateFromInputs());
  });
  scheduleDateInput.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    event.preventDefault();
    const scheduleDate = readScheduleDateFromInputs();
    if (!scheduleDate) {
      showToast("Choose a valid schedule time.", "error");
      return;
    }
    scheduleActiveMessage(scheduleDate);
  });
}
if (scheduleTimeInput) {
  scheduleTimeInput.addEventListener("input", () => {
    updateSchedulePreview(readScheduleDateFromInputs());
  });
  scheduleTimeInput.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    event.preventDefault();
    const scheduleDate = readScheduleDateFromInputs();
    if (!scheduleDate) {
      showToast("Choose a valid schedule time.", "error");
      return;
    }
    scheduleActiveMessage(scheduleDate);
  });
}
schedulePresetButtons.forEach((btn) => {
  btn.addEventListener("click", () => {
    const minutes = Number(btn.dataset.scheduleMinutes);
    if (!Number.isFinite(minutes) || minutes <= 0) return;
    const scheduleDate = new Date(Date.now() + minutes * 60 * 1000);
    setScheduleInputFromDate(scheduleDate);
    scheduleActiveMessage(scheduleDate);
  });
});
if (scheduledPanelToggleBtn) {
  scheduledPanelToggleBtn.addEventListener("click", () => {
    setScheduledPanelExpanded(!scheduledPanelExpanded);
  });
}
document.addEventListener("click", (event) => {
  if (!isScheduleMenuOpen()) return;
  const target = event.target;
  if (!(target instanceof Element)) return;
  if (scheduleMenu && scheduleMenu.contains(target)) return;
  if (scheduleBtn && scheduleBtn.contains(target)) return;
  closeScheduleMenu();
});
document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") return;
  if (!isScheduleMenuOpen()) return;
  closeScheduleMenu();
});
if (retryFailedBtn) {
  retryFailedBtn.addEventListener("click", (event) => {
    event.preventDefault();
    retryAllFailedMessages();
  });
}

if (attachFileBtn && attachFileInput) {
  attachFileBtn.addEventListener("click", () => {
    if (!activeFriend) {
      showToast("Choose a friend before attaching a file.", "error");
      return;
    }
    const safety = getFriendSafety(activeFriend, activeChatKind);
    if (safety.blocked) {
      showToast(safety.blockedByMe ? "Unblock this contact to share files." : "This user has blocked you.", "error");
      return;
    }
    if (attachmentUploadState.active) {
      showToast("Please wait for the current upload to finish.", "info");
      return;
    }
    attachFileInput.value = "";
    attachFileInput.click();
  });

  attachFileInput.addEventListener("change", async () => {
    const selectedFile = attachFileInput.files && attachFileInput.files[0];
    if (!selectedFile) return;
    await uploadAttachmentFromPicker(selectedFile);
  });
}

if (cameraBtn) {
  cameraBtn.addEventListener("click", () => {
    void openComposerCameraCapture();
  });
}

if (cameraCaptureInput) {
  cameraCaptureInput.addEventListener("change", async () => {
    const selectedPhoto = cameraCaptureInput.files && cameraCaptureInput.files[0];
    if (!selectedPhoto) return;
    await uploadAttachmentFromPicker(selectedPhoto);
  });
}

if (voiceBtn) {
  voiceBtn.addEventListener("click", () => {
    if (voiceState.isRecording) {
      stopVoiceRecording();
    } else {
      startVoiceRecording();
    }
  });
}
if (voiceCancelBtn) {
  voiceCancelBtn.addEventListener("click", () => stopVoiceRecording(true));
}
if (voiceStopBtn) {
  voiceStopBtn.addEventListener("click", () => stopVoiceRecording(false));
}

if (callButton) {
  callButton.addEventListener("click", () => {
    startVoiceCall();
  });
}
if (videoButton) {
  videoButton.addEventListener("click", () => {
    startVideoCall();
  });
}
if (profileCallBtn) {
  profileCallBtn.addEventListener("click", () => {
    startVoiceCall();
  });
}
if (profileVideoBtn) {
  profileVideoBtn.addEventListener("click", () => {
    startVideoCall();
  });
}
if (infoCallBtn) {
  infoCallBtn.addEventListener("click", () => {
    startVoiceCall();
  });
}
if (infoMuteBtn) {
  infoMuteBtn.addEventListener("click", () => {
    if (!activeFriend) return;
    const safety = getFriendSafety(activeFriend, activeChatKind);
    socket.emit("set_mute", {
      username: activeFriend,
      muted: !safety.muted,
    });
  });
}
if (infoBlockBtn) {
  infoBlockBtn.addEventListener("click", () => {
    if (!activeFriend) return;
    const safety = getFriendSafety(activeFriend, activeChatKind);
    socket.emit("set_block", {
      username: activeFriend,
      blocked: !safety.blockedByMe,
    });
  });
}
if (infoReportBtn) {
  infoReportBtn.addEventListener("click", async () => {
    if (!activeFriend) return;
    const reason = await appDialog.openPrompt({
      title: `Report @${activeFriend}`,
      description: "Tell us what happened. Your report helps keep chat safe.",
      label: "Reason",
      defaultValue: "Spam or harassment",
      placeholder: "Describe the issue",
      confirmText: "Submit report",
      danger: true,
      multiline: true,
      maxLength: 320,
    });
    if (reason === null) return;
    const trimmedReason = String(reason || "").trim();
    if (!trimmedReason) {
      showToast("Please enter a reason.", "error");
      return;
    }
    socket.emit("report_user", {
      username: activeFriend,
      category: "other",
      reason: trimmedReason,
    });
  });
}
if (infoAddMembersBtn) {
  infoAddMembersBtn.addEventListener("click", () => {
    openAddGroupMembersPrompt();
  });
}
if (infoToggleBtn) {
  infoToggleBtn.addEventListener("click", () => {
    window.setTimeout(() => {
      if (!document.body || !document.body.classList.contains("info-open")) return;
      syncInfoPanel();
      if (normalizeChatKind(activeChatKind) === "group") {
        const groupId = resolveGroupChatId(activeFriend, "group");
        if (groupId) requestGroupInfo(groupId, { kind: "group", force: true });
      }
    }, 60);
  });
}
if (callMuteBtn) callMuteBtn.addEventListener("click", toggleMute);
if (callSpeakerBtn) callSpeakerBtn.addEventListener("click", toggleSpeaker);
if (callCameraBtn) callCameraBtn.addEventListener("click", toggleCamera);
if (callFlipBtn) callFlipBtn.addEventListener("click", switchCamera);
if (callAcceptBtn) callAcceptBtn.addEventListener("click", acceptIncomingCall);
if (callRejectBtn) callRejectBtn.addEventListener("click", rejectIncomingCall);
if (callHangupBtn) callHangupBtn.addEventListener("click", hangupCall);
if (callMinimizeBtn) callMinimizeBtn.addEventListener("click", () => setCallMinimized(true));
if (callMiniEnd) {
  callMiniEnd.addEventListener("click", (event) => {
    event.stopPropagation();
    hangupCall();
  });
}
if (callMini) {
  callMini.addEventListener("click", (event) => {
    if (callMiniEnd && callMiniEnd.contains(event.target)) return;
    setCallMinimized(false);
  });
}

messageInput.addEventListener("input", () => {
  if (messageInput.value.length > COMPOSER_MAX_MESSAGE_LENGTH) {
    messageInput.value = messageInput.value.slice(0, COMPOSER_MAX_MESSAGE_LENGTH);
  }
  if (sendButton) {
    sendButton.classList.toggle("ready", messageInput.value.trim().length > 0);
  }
  if (!activeFriend) return;
  setMessageDraft(activeFriend, messageInput.value);
  messageInput.value.trim() ? markLocalTyping() : stopLocalTyping();
});

if (messageSearchInput) {
  messageSearchInput.addEventListener("input", applyMessageSearch);
  messageSearchInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      if (getSearchScope() === "global") {
        applyMessageSearch();
        return;
      }
      jumpSearchResult(e.shiftKey ? -1 : 1);
    }
  });
}
if (messageSearchScope) {
  messageSearchScope.addEventListener("change", () => {
    applyMessageSearch();
    if (messageSearchInput) messageSearchInput.focus();
  });
}
if (messageSearchFilter) {
  messageSearchFilter.addEventListener("change", () => {
    if (getSearchScope() === "global") {
      applyMessageSearch();
    }
  });
}
if (messageSearchPrev) {
  messageSearchPrev.addEventListener("click", () => jumpSearchResult(-1));
}
if (messageSearchNext) {
  messageSearchNext.addEventListener("click", () => jumpSearchResult(1));
}
if (messageSearchToggle) {
  messageSearchToggle.addEventListener("click", (e) => {
    e.stopPropagation();
    if (searchPanelOpen) {
      closeMessageSearchPanel();
    } else {
      openMessageSearchPanel();
    }
  });
}
if (messageSearchPanel) {
  messageSearchPanel.addEventListener("click", (e) => e.stopPropagation());
}
if (messageSearchClear) {
  messageSearchClear.addEventListener("click", () => {
    if (messageSearchInput) messageSearchInput.value = "";
    applyMessageSearch();
    if (messageSearchInput) messageSearchInput.focus();
  });
}
if (contactsRequestsBtn) {
  contactsRequestsBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    const next = !contactsRequestsPanel?.classList.contains("is-open");
    setRequestsPanelOpen(next);
  });
}
document.addEventListener("click", () => {
  if (searchPanelOpen) closeMessageSearchPanel();
});
document.addEventListener("click", (e) => {
  if (!contactsRequestsPanel || !contactsRequestsBtn) return;
  if (!contactsRequestsPanel.classList.contains("is-open")) return;
  if (e.target.closest("#contactsRequestsPanel") || e.target.closest("#contactsRequestsBtn")) return;
  setRequestsPanelOpen(false);
});
document.addEventListener("keydown", (e) => {
  const isFindShortcut = (e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "f";
  if (isFindShortcut) {
    e.preventDefault();
    openMessageSearchPanel();
    return;
  }

  if (e.key === "Escape" && contactsRequestsPanel?.classList.contains("is-open")) {
    setRequestsPanelOpen(false);
    return;
  }
  if (e.key === "Escape" && searchPanelOpen) {
    if (getSearchQuery()) {
      if (messageSearchInput) messageSearchInput.value = "";
      applyMessageSearch();
      return;
    }
    closeMessageSearchPanel();
  }
});

// Stop typing indicator when input loses focus
if (messageInput) {
  messageInput.addEventListener("focus", () => {
    syncViewportLayoutMetrics();
    setTimeout(syncViewportLayoutMetrics, 40);
  });
  messageInput.addEventListener("blur", () => {
    stopLocalTyping();
    setTimeout(syncViewportLayoutMetrics, 80);
  });

  // Allow Shift+Enter to send (optional quality-of-life)
  messageInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey && !messageInput.disabled) {
      e.preventDefault();
      sendActiveMessage();
    }
  });
}

setInterval(() => {
  flushPendingPresenceSync();
  if (!pendingQueue.length) return;
  flushPendingQueue();
}, PENDING_RETRY_TICK_MS);

window.addEventListener("online", () => {
  syncBrowserNetworkState();
  flushPendingQueue(true);
  flushPendingPresenceSync();
});

window.addEventListener("offline", () => {
  syncBrowserNetworkState();
  if (pendingQueue.length) {
    const label = pendingQueue.length === 1 ? "message is" : "messages are";
    showToast(`${pendingQueue.length} queued ${label} waiting for connection.`, "info");
  }
});

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Socket events Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

socket.on("register_success", (data) => {
  const previousActiveFriend = activeFriend;
  const previousActiveChatKind = activeChatKind;
  persistActiveMessageDraft();
  me           = data.username;
  ensureMessageDraftsLoaded(true);
  friends      = Array.isArray(data.friends) ? data.friends.map((friend) => sanitizeFriendRecord(friend)) : [];
  groupInfoState.byId.clear();
  groupInfoState.requestedAt.clear();
  requests     = data.requests || [];
  applySafetyState(data.safety || {});
  activeFriend = "";
  activeChatKind = "friend";
  setActiveChatTarget("");

  if (data.profile) {
    myProfile.avatarId    = data.profile.avatarId || "";
    myProfile.displayName = data.profile.displayName || "";
    myProfile.age         = data.profile.age || "";
    myProfile.gender      = data.profile.gender || "";
    myProfile.bio         = data.profile.bio || "";
    myProfile.email       = data.email || "";
  } else {
    myProfile.avatarId    = "";
    myProfile.displayName = "";
    myProfile.age         = "";
    myProfile.gender      = "";
    myProfile.bio         = "";
    myProfile.email       = data.email || "";
  }
  manualPresenceMode = normalizePresenceMode(data?.presenceMode, "online");
  myPresenceMode = manualPresenceMode;
  pendingPresenceSyncMode = "";
  presenceAutoAwayActive = false;
  window._novynProfile  = myProfile;
  renderMyName();
  applyMyAvatar();
  syncSettingsPanel();
  clearSidebarSearch();
  if (passwordInput) passwordInput.value = "";
  if (activeFriendLabel) activeFriendLabel.textContent = "Select a conversation";
  renderActiveFriendPresence();
  syncRemoveFriendButton();
  syncSafetyActionButtons();

  if (loginCard) loginCard.classList.add("hidden");
  if (chatLayout) chatLayout.classList.remove("hidden");

  clearUsernameSuggestions();
  setLoginLoading(false);
  resumeSocketSession._pending = false;
  setComposerEnabled(false);
  renderMessagesEmptyState(EMPTY_CONVERSATION_HINT);
  syncBrowserNetworkState();

  const restoredPendingCount = restorePendingState(true);
  syncPendingPreviewIntoFriendList();
  if (restoredPendingCount > 0 && !restoredPendingToastShown) {
    restoredPendingToastShown = true;
    const label = restoredPendingCount === 1 ? "message" : "messages";
    showToast(`Recovered ${restoredPendingCount} unsent ${label}.`, "info");
  }
  flushPendingQueue(true);
  pendingPresenceSyncMode = myPresenceMode;
  flushPendingPresenceSync();
  schedulePresenceActivityTimers();

  renderRequests();
  renderFriends();
  renderScheduledPanel();
  renderDiscover();
  if (sidebarView === "discover") {
    requestDiscoverOnline();
  }
  if (
    previousActiveFriend &&
    friends.some((friend) => isSameChatTarget(
      friend.username,
      friend.kind || "friend",
      previousActiveFriend,
      previousActiveChatKind
    ))
  ) {
    setActiveFriend(previousActiveFriend, previousActiveChatKind);
  }
  if (!hasGreeted) {
    hasGreeted = true;
    showToast(`Welcome to Novyn, @${me}!`, "success");
  }
  ensurePushSubscription(false);
});

socket.on("username_unavailable", (data) => {
  const requested   = data?.requested   || "This username";
  const suggestions = data?.suggestions || [];
  showUsernameSuggestions(requested, suggestions);
  resumeSocketSession._pending = false;
  setLoginLoading(false);
  showToast("Username already taken.", "error");
});

socket.on("auth_failed", (data) => {
  const message     = data?.message     || "Authentication failed.";
  const suggestions = data?.suggestions || [];
  resumeSocketSession._pending = false;
  if (isDashboardPage) {
    clearStoredSession();
    if (!logoutInProgress) {
      showToast(message, "error");
    }
    redirectToLogin();
    return;
  }
  if (Array.isArray(suggestions) && suggestions.length) {
    showUsernameSuggestions(usernameInput ? usernameInput.value.trim() || "This username" : "This username", suggestions);
  }
  setLoginLoading(false);
  showToast(message, "error");
});

socket.on("friend_suggestions", (data) => {
  const query = String(data?.query || "").trim();
  const suggestions = data?.suggestions || [];
  if (!friendInput) return;
  const current = friendInput.value.trim();
  if (!query || normalizeSearchText(query) !== normalizeSearchText(current)) return;
  showFriendSuggestions(query, suggestions);
});

socket.on("discover_online", (data) => {
  setDiscoverUsers(data?.users || []);
});

socket.on("global_search_results", (data) => {
  const scope = getSearchScope();
  if (scope !== "global") return;
  const requestId = Number(data?.requestId);
  if (Number.isFinite(requestId) && requestId !== globalSearchState.requestId) return;
  const query = normalizeSearchText(data?.query || "");
  const currentQuery = normalizeSearchText(messageSearchInput ? messageSearchInput.value : "");
  const filter = String(data?.filter || "").toLowerCase();
  const currentFilter = getSearchFilter();
  if (query !== currentQuery || filter !== currentFilter) return;

  globalSearchState.loading = false;
  globalSearchState.results = Array.isArray(data?.results) ? data.results : [];
  renderGlobalSearchResults();
  if (messageSearchCount) {
    messageSearchCount.classList.remove("hidden");
    const count = globalSearchState.results.length;
    messageSearchCount.textContent = `${count} result${count === 1 ? "" : "s"}`;
  }
});

socket.on("scheduled_message_created", (data) => {
  const message = data?.message;
  if (!message?.id) return;
  const chatKey = getScheduledChatKey(message.to, message.toType);
  const current = scheduledState.byChat.get(chatKey) || [];
  const next = current.concat([message]).sort((a, b) => String(a?.sendAt || "").localeCompare(String(b?.sendAt || "")));
  scheduledState.byChat.set(chatKey, next);
  renderScheduledPanel();
});

socket.on("scheduled_messages_updated", (data) => {
  const to = String(data?.to || "").trim();
  const kind = normalizeChatKind(data?.toType || "friend");
  if (!to) return;
  setScheduledMessagesForChat(to, kind, data?.messages || []);
  if (activeFriend && isSameChatTarget(to, kind, activeFriend, activeChatKind)) {
    renderScheduledPanel();
  }
});

socket.on("scheduled_message_cancelled", (data) => {
  const id = String(data?.id || "").trim();
  if (id) showToast("Scheduled message cancelled.", "info");
  requestScheduledMessagesForActiveChat();
});

socket.on("scheduled_message_sent", () => {
  showToast("Scheduled message sent.", "success");
  requestScheduledMessagesForActiveChat();
});

socket.on("scheduled_message_failed", (data) => {
  const reason = String(data?.reason || "").trim();
  showToast(reason || "Scheduled message could not be delivered.", "error");
  requestScheduledMessagesForActiveChat();
});

socket.on("group_info", (data) => {
  const normalized = normalizeGroupInfoPayload(data?.group || data);
  if (!normalized) return;
  const groupKey = normalizeName(normalized.id);
  groupInfoState.byId.set(groupKey, normalized);

  const onlineCount = normalized.members.reduce((count, member) => (
    member.online && normalizeName(member.username) !== normalizeName(me) ? count + 1 : count
  ), 0);
  friends = friends.map((friend) => {
    if (!isSameChatTarget(friend?.username, friend?.kind || "friend", normalized.id, "group")) {
      return friend;
    }
    return {
      ...friend,
      displayName: normalized.name || friend.displayName,
      memberCount: normalized.members.length,
      onlineCount,
      online: onlineCount > 0,
    };
  });

  if (activeFriend && isSameChatTarget(activeFriend, activeChatKind, normalized.id, "group")) {
    syncInfoPanel();
    renderActiveFriendPresence();
  }
  renderFriends();
});

socket.on("group_created", (data) => {
  const groupName = String(data?.group?.name || "").trim();
  if (groupName) {
    showToast(`Group created: ${groupName}`, "success");
  } else {
    showToast("Group created.", "success");
  }
});

socket.on("group_members_added", (data) => {
  const groupName = String(data?.groupName || data?.groupId || "").trim();
  const added = Array.isArray(data?.added) ? data.added : [];
  if (!groupName || !added.length) return;
  showToast(`${added.join(", ")} added to ${groupName}.`, "success");
  const groupId = String(data?.groupId || "").trim();
  if (groupId) refreshActiveGroupInfo(groupId);
});

socket.on("group_member_left", (data) => {
  const groupName = String(data?.groupName || data?.groupId || "").trim();
  const username = String(data?.username || "").trim();
  if (!groupName || !username) return;
  showToast(`${username} left ${groupName}.`, "info");
  const groupId = String(data?.groupId || "").trim();
  if (groupId) refreshActiveGroupInfo(groupId);
});

socket.on("group_member_removed", (data) => {
  const groupName = String(data?.groupName || data?.groupId || "").trim();
  const username = String(data?.username || "").trim();
  if (groupName && username) {
    showToast(`${username} was removed from ${groupName}.`, "info");
  }
  const groupId = String(data?.groupId || "").trim();
  if (groupId) refreshActiveGroupInfo(groupId);
});

socket.on("group_member_role_updated", (data) => {
  const groupName = String(data?.groupName || data?.groupId || "").trim();
  const username = String(data?.username || "").trim();
  const role = String(data?.role || "").trim().toLowerCase();
  if (groupName && username) {
    const roleLabel = role === "admin" ? "admin" : "member";
    showToast(`${username} is now ${roleLabel} in ${groupName}.`, "success");
  }
  const groupId = String(data?.groupId || "").trim();
  if (groupId) refreshActiveGroupInfo(groupId);
});

socket.on("group_left", (data) => {
  const groupId = String(data?.groupId || "").trim();
  if (groupId) {
    const groupKey = normalizeName(groupId);
    groupInfoState.byId.delete(groupKey);
    groupInfoState.requestedAt.delete(groupKey);
  }
  if (activeFriend && normalizeName(activeFriend) === normalizeName(groupId) && normalizeChatKind(activeChatKind) === "group") {
    clearActiveFriendSelection();
  }
  const wasRemoved = String(data?.reason || "").trim().toLowerCase() === "removed";
  showToast(wasRemoved ? "You were removed from the group." : "You left the group.", "info");
});

socket.on("mute_updated", (data) => {
  const username = String(data?.username || "").trim();
  const key = normalizeName(username);
  if (!key) return;
  if (data?.muted) safetyState.muted.add(key);
  else safetyState.muted.delete(key);
  friends = friends.map((friend) =>
    normalizeName(friend?.username) === key
      ? { ...friend, muted: Boolean(data?.muted) }
      : friend
  );
  renderFriends();
  syncActiveConversationAccess();
  showToast(data?.muted ? `Muted @${username}` : `Unmuted @${username}`, "success");
});

socket.on("block_updated", (data) => {
  const username = String(data?.username || "").trim();
  const key = normalizeName(username);
  if (!key) return;
  if (data?.blocked) safetyState.blocked.add(key);
  else safetyState.blocked.delete(key);
  friends = friends.map((friend) =>
    normalizeName(friend?.username) === key
      ? { ...friend, blockedByMe: Boolean(data?.blocked), muted: data?.blocked ? false : friend.muted }
      : friend
  );
  renderFriends();
  syncActiveConversationAccess();
  const label = data?.blocked ? `Blocked @${username}` : `Unblocked @${username}`;
  showToast(label, "success");
});

socket.on("report_submitted", (data) => {
  const username = String(data?.username || "").trim();
  showToast(username ? `Report submitted for @${username}.` : "Report submitted. Thanks for helping keep chat safe.", "success");
});

socket.on("chat_cleared", (data) => {
  const payloadKind = normalizeChatKind(data?.toType || data?.kind || "friend");
  const payloadTarget = normalizeMojibakeText(data?.to || data?.with || "").trim();
  if (!payloadTarget) return;

  friends = friends.map((friend) => (
    isSameChatTarget(friend?.username, friend?.kind || "friend", payloadTarget, payloadKind)
      ? {
          ...friend,
          unreadCount: 0,
          lastMessage: "",
          lastTimestamp: "",
          lastFrom: "",
        }
      : friend
  ));

  const isActiveTarget = Boolean(
    activeFriend && isSameChatTarget(payloadTarget, payloadKind, activeFriend, activeChatKind)
  );
  if (isActiveTarget) {
    pendingUnreadJump = { friendKey: "", count: 0 };
    conversationMessages = [];
    clearReply();
    resetMessageSearch();
    renderMessages([]);
  }

  renderFriends();
  syncRemoveFriendButton();

  const actor = String(data?.by || "").trim();
  const actorIsMe = actor && normalizeName(actor) === normalizeName(me);
  const chatEntry = getChatEntry(payloadTarget, payloadKind);
  const chatLabel = getFriendDisplayName(chatEntry || { username: payloadTarget, displayName: payloadTarget });
  if (!actorIsMe && actor) {
    showToast(`${actor} cleared messages in ${chatLabel}.`, "info");
    return;
  }
  if (isActiveTarget) {
    showToast(payloadKind === "group" ? `Cleared chat history for ${chatLabel}.` : "Cleared chat history.", "success");
  }
});

socket.on("friend_request_received", (data) => {
  showToast(`${data.from} sent you a friend request`);
  if (!requests.includes(data.from)) {
    requests = [...requests, data.from];
    renderRequests();
    renderDiscover();
  }
  playIncomingPing();
});

socket.on("friend_request_sent", (data) => {
  showToast(`Request sent to ${data.to}`, "success");
  const target = String(data?.to || "").trim();
  if (target) {
    discoverUsers = discoverUsers.filter((user) => normalizeName(user?.username) !== normalizeName(target));
    renderDiscover();
  }
});

socket.on("requests_updated", (data) => {
  requests = data.requests || [];
  renderRequests();
  renderDiscover();
});

socket.on("friend_request_accepted", (data) => {
  showToast(`${data.by} is now your friend!`, "success");
});

socket.on("friend_list_updated", (data) => {
  friends = Array.isArray(data.friends) ? data.friends.map((friend) => sanitizeFriendRecord(friend)) : [];
  const nextMuted = new Set();
  const nextBlocked = new Set(safetyState.blocked);
  friends.forEach((friend) => {
    const key = normalizeName(friend?.username);
    if (!key) return;
    if (friend?.muted) nextMuted.add(key);
    else nextMuted.delete(key);
    if (friend?.blockedByMe) nextBlocked.add(key);
    else nextBlocked.delete(key);
  });
  safetyState.muted = nextMuted;
  safetyState.blocked = nextBlocked;
  const availableGroupKeys = new Set(
    friends
      .filter((friend) => normalizeChatKind(friend?.kind || "friend") === "group")
      .map((friend) => normalizeName(friend?.username))
      .filter(Boolean)
  );
  Array.from(groupInfoState.byId.keys()).forEach((groupKey) => {
    if (!availableGroupKeys.has(groupKey)) {
      groupInfoState.byId.delete(groupKey);
      groupInfoState.requestedAt.delete(groupKey);
    }
  });
  friends.forEach((friend) => {
    if (normalizeChatKind(friend?.kind || "friend") !== "friend") return;
    const rawText = friend?.lastMessage || "";
    if (!rawText) return;
    if (!parseCallLogPayload(rawText)) return;
    addCallHistoryEntry({
      friend: friend.username || "",
      text: rawText,
      timestamp: friend.lastTimestamp || "",
      from: friend.lastFrom || friend.username || "",
    });
  });

  // If current chat partner was removed, reset
  if (activeFriend) {
    const stillThere = friends.some(
      (f) => isSameChatTarget(f.username, f.kind || "friend", activeFriend, activeChatKind)
    );
    if (!stillThere) {
      removeMessageDraft(activeFriend);
      activeFriend                  = "";
      activeChatKind               = "friend";
      conversationMessages          = [];
      activeFriendLabel.textContent = "Select a conversation";
      setComposerEnabled(false);
      if (messageInput) messageInput.value = "";
      if (sendButton) sendButton.classList.remove("ready");
      renderMessagesEmptyState(EMPTY_CONVERSATION_HINT);
      resetMessageSearch();
      renderActiveFriendPresence();
      syncRemoveFriendButton();
    }
  }

  renderFriends();
  syncActiveConversationAccess();
  renderScheduledPanel();
  renderCallHistory();
  renderDiscover();
  refreshActiveGroupInfo();
  if (sidebarView === "discover") {
    requestDiscoverOnline();
  }
});

socket.on("friend_removed", (data) => {
  const removedUsername = String(data?.username || "").trim();
  const removedKey = normalizeName(removedUsername);
  const activeKey = normalizeName(activeFriend);
  if (removedKey) {
    safetyState.muted.delete(removedKey);
  }
  if (removedUsername) removeMessageDraft(removedUsername);

  if (activeFriend && removedKey && activeKey === removedKey) {
    stopLocalTyping(activeFriend);
    activeFriend = "";
    activeChatKind = "friend";
    setActiveChatTarget("");
    conversationMessages = [];
    clearReply();
    activeFriendLabel.textContent = "Select a conversation";
    setComposerEnabled(false);
    if (messageInput) messageInput.value = "";
    if (sendButton) sendButton.classList.remove("ready");
    hideTypingIndicator();
    renderMessagesEmptyState(EMPTY_CONVERSATION_HINT);
    resetMessageSearch();
    renderActiveFriendPresence();
    syncRemoveFriendButton();
  }

  const actor = String(data?.by || "").trim();
  if (actor && normalizeName(actor) !== normalizeName(me)) {
    showToast(`${actor} removed you from friends.`);
  } else if (removedUsername) {
    showToast(`${removedUsername} removed from friends.`);
  }
});

socket.on("friend_username_changed", (data) => {
  const oldUsername = String(data?.oldUsername || "").trim();
  const newUsername = String(data?.newUsername || "").trim();
  if (!oldUsername || !newUsername) return;
  const oldKey = normalizeName(oldUsername);
  const newKey = normalizeName(newUsername);
  renameMessageDraft(oldUsername, newUsername);
  if (safetyState.muted.has(oldKey)) {
    safetyState.muted.delete(oldKey);
    safetyState.muted.add(newKey);
  }
  if (safetyState.blocked.has(oldKey)) {
    safetyState.blocked.delete(oldKey);
    safetyState.blocked.add(newKey);
  }

  if (activeFriend && normalizeName(activeFriend) === oldKey) {
    activeFriend = newUsername;
    setActiveChatTarget(activeFriend);
  }

  requests = requests.map((name) =>
    normalizeName(name) === oldKey ? newUsername : name
  );
  friends = friends.map((f) =>
    normalizeName(f.username) === oldKey ? { ...f, username: newUsername } : f
  );

  if (conversationMessages.length) {
    let touched = false;
    for (const msg of conversationMessages) {
      if (normalizeName(msg.from) === oldKey) { msg.from = newUsername; touched = true; }
      if (normalizeName(msg.to) === oldKey) { msg.to = newUsername; touched = true; }
      if (normalizeName(msg.fromKey) === oldKey) { msg.fromKey = newKey; touched = true; }
      if (normalizeName(msg.toKey) === oldKey) { msg.toKey = newKey; touched = true; }
      if (msg.replyTo && normalizeName(msg.replyTo.from) === oldKey) {
        msg.replyTo.from = newUsername;
        touched = true;
      }
    }
    if (touched) renderMessages(conversationMessages);
  }

  renderRequests();
  renderFriends();
  renderActiveFriendPresence();
  syncInfoPanel();
});

socket.on("username_changed", (data) => {
  const oldUsername = String(data?.oldUsername || "").trim();
  const newUsername = String(data?.newUsername || "").trim();
  if (!newUsername) return;
  const oldKey = normalizeName(oldUsername || me);
  const newKey = normalizeName(newUsername);
  persistActiveMessageDraft();
  migrateMessageDraftStoreOwner(oldKey, newKey);
  migratePendingStateStoreOwner(oldKey, newKey);
  if (normalizeName(me) === oldKey) {
    me = newUsername;
    ensureMessageDraftsLoaded(true);
    restorePendingState(true);
    renderMyName();
    applyMyAvatar();
    syncSettingsPanel();
    refreshAuthSessionSilently();
    applyActiveMessageDraft();
  }
  if (conversationMessages.length) {
    let touched = false;
    for (const msg of conversationMessages) {
      if (normalizeName(msg.from) === oldKey) { msg.from = newUsername; touched = true; }
      if (normalizeName(msg.to) === oldKey) { msg.to = newUsername; touched = true; }
      if (normalizeName(msg.fromKey) === oldKey) { msg.fromKey = newKey; touched = true; }
      if (normalizeName(msg.toKey) === oldKey) { msg.toKey = newKey; touched = true; }
      if (msg.replyTo && normalizeName(msg.replyTo.from) === oldKey) {
        msg.replyTo.from = newUsername;
        touched = true;
      }
    }
    if (touched) renderMessages(conversationMessages);
  }
  showToast(`Username updated to @${newUsername}`, "success");
});

socket.on("password_changed", () => {
  showToast("Password updated.", "success");
});

socket.on("history", (data) => {
  const payload = normalizeHistoryPayload(data);
  const incomingKind = normalizeChatKind(payload?.kind || payload?.toType || activeChatKind || "friend");
  const incomingKey = normalizeName(payload?.to || payload?.with || activeFriend || "");
  if (!incomingKey) return;
  if (!activeFriend) return;
  if (!isSameChatTarget(incomingKey, incomingKind, activeFriend, activeChatKind)) return;
  const messages = Array.isArray(payload?.messages)
    ? payload.messages.map((message) => sanitizeMessagePayload(message) || message)
    : [];
  cacheCallLogMessages(messages);
  renderMessages(messages);
  if (
    pendingMessageFocus.messageId &&
    pendingMessageFocus.friendKey &&
    normalizeName(incomingKey) === pendingMessageFocus.friendKey &&
    normalizeChatKind(pendingMessageFocus.kind) === incomingKind
  ) {
    const focused = revealAndFocusMessage(pendingMessageFocus.messageId);
    if (!focused) {
      showToast("That result is outside the loaded message window.", "info");
    }
    pendingMessageFocus = { friendKey: "", messageId: "", kind: "friend" };
  }
});

socket.on("private_message", (message) => {
  message = sanitizeMessagePayload(message) || message;
  const tempId = message?.clientTempId || "";
  const isOwnOutgoingMessage = normalizeName(message.from) === normalizeName(me);
  const messageKind = normalizeChatKind(message?.toType || (message?.groupId ? "group" : "friend"));
  const chatTargetRaw = messageKind === "group"
    ? (message?.groupId || message?.toKey || message?.to || "")
    : (isOwnOutgoingMessage ? message.to : message.from);
  const chatTarget = String(chatTargetRaw || "").trim();
  const isIncoming = !isOwnOutgoingMessage;
  const incomingSafety = isIncoming && messageKind === "friend" ? getFriendSafety(message.from, "friend") : null;
  const incomingMuted = Boolean(incomingSafety?.muted);

  if (tempId && isOwnOutgoingMessage) {
    removePendingFromQueue(tempId);
  }

  if (tempId && pendingByTempId.has(tempId) && isOwnOutgoingMessage) {
    const pendingMessage = pendingByTempId.get(tempId);
    Object.assign(pendingMessage, message, { pending: false, failed: false, clientTempId: tempId });
    pendingByTempId.delete(tempId);
    schedulePersistPendingState();
    renderNetworkState();

    const row = messagesEl.querySelector(`[data-client-temp-id="${tempId}"]`);
    if (row) {
      const replacement = buildMessageElement(pendingMessage, true);
      row.replaceWith(replacement);
      applyMessageSearch();
      return;
    }
  }

  if (tempId && isOwnOutgoingMessage) {
    const pendingIndex = conversationMessages.findIndex((entry) => entry?.clientTempId === tempId);
    if (pendingIndex >= 0) {
      const mergedMessage = {
        ...conversationMessages[pendingIndex],
        ...message,
        pending: false,
        failed: false,
        clientTempId: tempId,
      };
      conversationMessages[pendingIndex] = mergedMessage;

      const row = messagesEl ? messagesEl.querySelector(`[data-client-temp-id="${tempId}"]`) : null;
      if (row) {
        const replacement = buildMessageElement(mergedMessage, true);
        row.replaceWith(replacement);
        applyMessageSearch();
      }
      renderNetworkState();
      schedulePersistPendingState();
      return;
    }
    renderNetworkState();
    schedulePersistPendingState();
  }

  const cachedLog = cacheCallLogMessage(message);
  if (cachedLog) renderCallHistory();

  const isActiveThread = activeFriend
    && isSameChatTarget(chatTarget, messageKind, activeFriend, activeChatKind);

  if (chatTarget) {
    friends = friends.map((f) =>
      isSameChatTarget(f.username, f.kind || "friend", chatTarget, messageKind)
        ? { ...f, lastMessage: message.text, lastFrom: message.from, lastTimestamp: message.timestamp || f.lastTimestamp }
        : f
    );
    renderFriends();
  }

  if (!isActiveThread) {
    // Message is for a different conversation - just show a toast
    if (isIncoming && !incomingMuted) {
      const sender = findFriend(message.from, "friend");
      const senderName = sender ? getFriendDisplayName(sender) : message.from;
      const callPreview = formatCallLogPreview(message.text, false);
      const preview = callPreview || String(message.text || "");
      if (messageKind === "group") {
        const groupEntry = getChatEntry(chatTarget, "group");
        const groupName = groupEntry ? getFriendDisplayName(groupEntry) : (chatTarget || "Group");
        showToast(`${groupName} - ${senderName}: ${preview.slice(0, 40)}${preview.length > 40 ? "..." : ""}`);
      } else {
        showToast(`${senderName}: ${preview.slice(0, 40)}${preview.length > 40 ? "..." : ""}`);
      }
      playIncomingPing();
      notifyIncomingMessage(message, { senderName, force: true });
    }
    return;
  }

  if (isIncoming && !incomingMuted) {
    hideTypingIndicator();
    playIncomingPing();
    notifyIncomingMessage(message);
  }

  const nearBottomBeforeMessage = isNearBottom();
  const wasAtLatest = !hasNewerMessages();
  conversationMessages.push({
    ...message,
    toType: messageKind,
    groupId: messageKind === "group" ? (message.groupId || message.toKey || message.to || "") : "",
  });
  if (wasAtLatest) {
    messageWindowEnd = conversationMessages.length;
    appendMessage(conversationMessages[conversationMessages.length - 1]);
    const currentWindowSize = getCurrentMessageWindowSize();
    if (messagesEl && messagesEl.querySelectorAll("article.message").length > currentWindowSize) {
      messageWindowStart = Math.max(0, messageWindowEnd - currentWindowSize);
      renderMessageWindow({ maxVisible: currentWindowSize });
    }
  } else if (nearBottomBeforeMessage) {
    showLatestMessages();
  } else {
    syncLoadOlderButtonVisibility();
  }
  // Only bump the unread FAB counter for incoming messages, not our own
  if (normalizeName(message.from) !== normalizeName(me)) {
    if (window._novynFAB) window._novynFAB.bump();
  }
});

socket.on("delivery_blocked", (payload) => {
  const tempId = String(payload?.clientTempId || "").trim();
  if (tempId) {
    markPendingMessageFailed(tempId, { toast: false });
  }
  showToast("Message blocked by safety settings.", "error");
});

socket.on("message_status", (payload) => {
  const statusType = normalizeChatKind(payload?.toType || (payload?.groupId ? "group" : "friend"));
  const statusTarget = String(payload?.with || payload?.groupId || "").trim();
  if (!payload?.id || !statusTarget || !activeFriend) return;
  const matchesActiveThread = statusType === "group"
    ? normalizeName(resolveGroupChatId(activeFriend, activeChatKind)) === normalizeName(statusTarget)
    : isSameChatTarget(statusTarget, statusType, activeFriend, activeChatKind);
  if (!matchesActiveThread) return;
  let updatedMessage = null;
  for (const message of conversationMessages) {
    if (message.id !== payload.id) continue;
    if (payload.deliveredAt) message.deliveredAt = payload.deliveredAt;
    if (payload.seenAt) message.seenAt = payload.seenAt;
    if (statusType === "group" && Array.isArray(payload.seenBy)) {
      message.seenBy = Array.from(new Set(payload.seenBy.map((entry) => normalizeName(entry)).filter(Boolean)));
    }
    if (statusType === "group") {
      const seenCount = Number(payload.seenCount);
      const memberCount = Number(payload.memberCount);
      if (Number.isFinite(seenCount)) {
        message.seenCount = Math.max(0, Math.floor(seenCount));
      }
      if (Number.isFinite(memberCount)) {
        message.memberCount = Math.max(0, Math.floor(memberCount));
      }
    }
    updatedMessage = message;
    break;
  }
  const msgEl = messagesEl.querySelector(`[data-message-id="${payload.id}"]`);
  if (!msgEl || !msgEl.classList.contains("me")) return;
  const metaEl = msgEl.querySelector(".message-meta");
  if (!metaEl) return;
  const timeText = msgEl.dataset.timeLabel || prettyTime(msgEl.dataset.timestamp) || "";
  const fallbackSeen = statusType === "group"
    ? (
      Number(payload.seenCount) > 0
      || (
        Array.isArray(payload.seenBy)
        && payload.seenBy.some((entry) => normalizeName(entry) !== normalizeName(me))
      )
    )
    : Boolean(payload.seenAt);
  const statusKey = updatedMessage
    ? getMessageStatusKey(updatedMessage)
    : (fallbackSeen ? "seen" : payload.deliveredAt ? "delivered" : "sent");
  renderMineMessageMeta(metaEl, timeText, statusKey);
});

socket.on("typing", ({ from, isTyping, toType, to }) => {
  const speakingSource = String(speakingIndicator?.dataset?.source || speakingIndicatorState.source || "").trim();
  const voiceNoteSpeakingVisible = Boolean(
    speakingIndicator
    && !speakingIndicator.classList.contains("hidden")
    && speakingSource === "voice-note"
  );
  const kind = normalizeChatKind(toType || "friend");
  if (kind === "group") {
    if (!activeFriend || normalizeChatKind(activeChatKind) !== "group") return;
    const activeGroupId = resolveGroupChatId(activeFriend, "group");
    if (normalizeName(to) !== normalizeName(activeGroupId)) return;
    if (normalizeName(from) === normalizeName(me)) return;
    if (isTyping && voiceNoteSpeakingVisible) return;
    isTyping ? showTypingIndicator(from) : hideTypingIndicator();
    return;
  }
  if (!activeFriend || normalizeChatKind(activeChatKind) !== "friend") return;
  if (normalizeName(from) !== normalizeName(activeFriend)) return;
  if (getFriendSafety(from, "friend").muted) return;
  if (isTyping && voiceNoteSpeakingVisible) return;
  isTyping ? showTypingIndicator(from) : hideTypingIndicator();
});

socket.on("voice_activity", ({ from, isSpeaking, toType, to }) => {
  if (callState.status !== "idle") {
    hideSpeakingIndicator("voice-note");
    return;
  }
  const kind = normalizeChatKind(toType || "friend");
  if (kind === "group") {
    if (!activeFriend || normalizeChatKind(activeChatKind) !== "group") return;
    const activeGroupId = resolveGroupChatId(activeFriend, "group");
    if (normalizeName(to) !== normalizeName(activeGroupId)) return;
    if (normalizeName(from) === normalizeName(me)) return;
    if (isSpeaking) {
      hideTypingIndicator();
      showSpeakingIndicator(from, { source: "voice-note" });
    } else {
      hideSpeakingIndicator("voice-note");
    }
    return;
  }
  if (!activeFriend || normalizeChatKind(activeChatKind) !== "friend") return;
  if (normalizeName(from) !== normalizeName(activeFriend)) return;
  if (getFriendSafety(from, "friend").muted) return;
  if (isSpeaking) {
    hideTypingIndicator();
    showSpeakingIndicator(from, { source: "voice-note" });
  } else {
    hideSpeakingIndicator("voice-note");
  }
});

socket.on("call_invite", (data) => {
  const from = String(data?.from || "").trim();
  if (!from) return;
  const safety = getFriendSafety(from);
  if (safety.blocked || safety.muted) {
    socket.emit("call_reject", { to: from });
    return;
  }
  if (!INCOMING_CALLS_ENABLED) {
    socket.emit("call_reject", { to: from });
    showToast(`Missed call from ${getCallPeerDisplayName(from)}.`, "info");
    playIncomingPing();
    notifyIncomingCall(from, { blocked: true });
    return;
  }
  if (callState.status !== "idle") {
    socket.emit("call_reject", { to: from });
    return;
  }
  callState.peer = from;
  callState.isCaller = false;
  callState.status = "incoming";
  callState.mediaType = data?.type === "video" ? "video" : "audio";
  callState.videoEnabled = callState.mediaType === "video";
  callState.videoFacing = "user";
  callState.minimized = false;
  callState.logSent = false;
  stopCallTimer();
  updateCallUi();
  playIncomingPing();
  notifyIncomingCall(from);
});

socket.on("call_ringing", () => {
  if (callState.status === "outgoing") {
    callState.inviteAcknowledged = true;
    callState.status = "ringing";
    updateCallUi();
  }
});

socket.on("call_answer", (data) => {
  if (normalizeName(data?.from) !== normalizeName(callState.peer)) return;
  if (["outgoing", "ringing"].includes(callState.status)) {
    callState.inviteAcknowledged = true;
    clearCallRingTimeout();
    callState.status = "connecting";
    updateCallUi();
  }
});

socket.on("call_reject", (data) => {
  if (normalizeName(data?.from) !== normalizeName(callState.peer)) return;
  showToast(`${getCallPeerDisplayName(callState.peer)} declined the call.`, "info");
  maybeSendCallLog("declined");
  resetCallState();
});

socket.on("call_cancelled", (data) => {
  if (normalizeName(data?.from) !== normalizeName(callState.peer)) return;
  showToast(`${getCallPeerDisplayName(callState.peer)} cancelled the call.`, "info");
  maybeSendCallLog("cancelled");
  resetCallState();
});

socket.on("call_end", (data) => {
  if (normalizeName(data?.from) !== normalizeName(callState.peer)) return;
  showToast("Call ended.", "info");
  maybeSendCallLog("ended");
  resetCallState();
});

socket.on("call_busy", () => {
  showToast("Friend is already on another call.", "error");
  maybeSendCallLog("busy");
  resetCallState();
});

socket.on("call_unavailable", () => {
  showToast("Friend is offline or unavailable.", "error");
  maybeSendCallLog("unavailable");
  resetCallState();
});

socket.on("call_blocked", () => {
  showToast("Call blocked by safety settings.", "error");
  maybeSendCallLog("blocked");
  resetCallState();
});

socket.on("call_signal", (payload) => {
  handleCallSignal(payload).catch(() => {});
});

socket.on("user_status", ({ username, online, presence, lastSeenAt }) => {
  const nextPresence = normalizePresenceMode(presence, online ? "online" : "offline");
  const isOnline = Boolean(online) && nextPresence !== "offline";
  friends = friends.map((f) =>
    normalizeName(f.username) === normalizeName(username)
      ? {
          ...f,
          online: isOnline,
          presence: nextPresence,
          lastSeenAt: lastSeenAt || f.lastSeenAt || "",
        }
      : f
  );
  renderFriends();
  syncInfoPanel();
  if (sidebarView === "discover") {
    requestDiscoverOnline();
  }
});

socket.on("presence_mode_updated", (payload) => {
  pendingPresenceSyncMode = "";
  clearPresenceSyncTimer();
  const acknowledgedMode = normalizePresenceMode(payload?.status, myPresenceMode);
  if (!presenceAutoAwayActive) {
    manualPresenceMode = acknowledgedMode;
  }
  setMyPresenceMode(acknowledgedMode, { emit: false, toast: false, manual: false });
});

socket.on("error_message", (data) => {
  const message = String(data?.message || "Something went wrong");
  if (
    normalizeChatKind(activeChatKind) === "group"
    && /group not found/i.test(message)
    && groupMemberList
    && groupMembersMeta
  ) {
    groupMembersMeta.textContent = "0";
    groupMemberList.innerHTML = '<div class="group-member-empty">Unable to load members right now.</div>';
  }
  showToast(message, "error");
});

socket.on("connect", () => {
  syncBrowserNetworkState();
  void ensureDashboardSession(true);
  flushPendingQueue(true);
  flushPendingPresenceSync();
  schedulePresenceActivityTimers();
  requestScheduledMessagesForActiveChat();
  if (normalizeChatKind(activeChatKind) === "group" && activeFriend) {
    const groupId = resolveGroupChatId(activeFriend, "group");
    if (groupId) requestGroupInfo(groupId, { kind: "group", force: true });
  }
});

socket.on("disconnect", () => {
  stopLocalTyping();
  hideTypingIndicator();
  ensureDashboardSession._pending = null;
  resumeSocketSession._pending = false;
  syncBrowserNetworkState();
  clearPresenceActivityTimers();
  if (!logoutInProgress) {
    showToast("Disconnected from server", "error");
  }
  if (callState.status !== "idle") resetCallState();
});

socket.on("connect_error", () => {
  ensureDashboardSession._pending = null;
  resumeSocketSession._pending = false;
  syncBrowserNetworkState();
});

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Profile helpers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

function applyMyAvatar() {
  if (!meAvatar) return;
  const utils = window._novynAvatarUtils;
  if (utils && myProfile.avatarId) {
    utils.applyAvatarToEl(meAvatar, myProfile.avatarId, me.slice(0, 2).toUpperCase());
  } else {
    meAvatar.style.background = "";
    meAvatar.textContent = me.slice(0, 2).toUpperCase();
  }
}

socket.on("profile_updated", (data) => {
  myProfile.avatarId    = data.avatarId    || "";
  myProfile.displayName = data.displayName || "";
  myProfile.age         = data.age         || "";
  myProfile.gender      = data.gender      || "";
  myProfile.bio         = data.bio         || "";
  myProfile.email       = data.email       || "";
  window._novynProfile  = myProfile;
  renderMyName();
  applyMyAvatar();
  syncSettingsPanel();
  syncInfoPanel();
  showToast("Profile updated.", "success");
});

socket.on("friend_profile_updated", (data) => {
  friends = friends.map((f) =>
    normalizeName(f.username) === normalizeName(data.username)
      ? { ...f, avatarId: data.avatarId, displayName: data.displayName, bio: data.bio || "" }
      : f
  );
  renderFriends();
  syncInfoPanel();
});

socket.on("reaction_updated", (payload) => {
  if (!payload?.messageId) return;
  applyConversationReactionsUpdate(payload.messageId, payload.reactions);
  if (window._novynReactions) {
    window._novynReactions.applyServerReactions(payload.messageId, payload.reactions);
  }
});

socket.on("safety_state_updated", (data) => {
  applySafetyState(data || {});
  renderFriends();
  syncActiveConversationAccess();
});

socket.on("message_edited", (payload) => {
  if (!payload?.messageId || !payload?.with) return;
  const payloadKind = normalizeChatKind(payload?.toType || "friend");
  if (!activeFriend || !isSameChatTarget(payload.with, payloadKind, activeFriend, activeChatKind)) return;
  if (!applyConversationMessageEdit(payload.messageId, payload.text, payload.editedAt)) return;
  rerenderConversationMessageRow(payload.messageId);
  applyMessageSearch();
  syncPinnedMessageBar();
});

socket.on("message_pin_updated", (payload) => {
  if (!payload?.messageId || !payload?.with) return;
  const payloadKind = normalizeChatKind(payload?.toType || "friend");
  if (!activeFriend || !isSameChatTarget(payload.with, payloadKind, activeFriend, activeChatKind)) return;
  if (!applyConversationMessagePin(payload.messageId, payload.pinned, payload.pinnedAt, payload.pinnedBy)) return;
  rerenderConversationMessageRow(payload.messageId);
  applyMessageSearch();
  syncPinnedMessageBar();
});

socket.on("message_deleted", (payload) => {
  if (!payload?.messageId || !payload?.with) return;
  const payloadKind = normalizeChatKind(payload?.toType || "friend");
  if (!activeFriend || !isSameChatTarget(payload.with, payloadKind, activeFriend, activeChatKind)) return;

  markConversationMessageDeleted(payload.messageId, payload.deletedAt, payload.text || DELETED_MESSAGE_TEXT);
  applyDeletedMessageToDom(payload.messageId, payload.text || DELETED_MESSAGE_TEXT);
  applyMessageSearch();
  syncPinnedMessageBar();
});

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Init Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
syncViewportLayoutMetrics();
if (isDashboardPage) {
  loadNovynLabsState();
}
setComposerEnabled(false);
renderActiveFriendPresence();
syncRemoveFriendButton();
syncSafetyActionButtons();
syncMessageSearchUi();
if (messagesEl) {
  messagesEl.addEventListener("scroll", () => {
    if (isMessageViewportMutationActive()) return;
    scrollState.pinnedToBottom = isNearBottom();
    syncLoadOlderButtonVisibility();
  }, { passive: true });
}
if (messagesEl && typeof ResizeObserver !== "undefined") {
  const messagesResizeObserver = new ResizeObserver(() => {
    if (!activeFriend) return;
    if (isMessageViewportMutationActive()) {
      syncLoadOlderButtonVisibility();
      return;
    }
    if (scrollState.pinnedToBottom) scrollToBottom(true);
    syncLoadOlderButtonVisibility();
  });
  messagesResizeObserver.observe(messagesEl);
}
window.addEventListener("resize", () => {
  syncViewportLayoutMetrics();
  if (!activeFriend) return;
  if (isMessageViewportMutationActive()) {
    syncLoadOlderButtonVisibility();
    return;
  }
  if (scrollState.pinnedToBottom) scrollToBottom(true);
  syncLoadOlderButtonVisibility();
}, { passive: true });
if (window.visualViewport) {
  window.visualViewport.addEventListener("resize", syncViewportLayoutMetrics, { passive: true });
  window.visualViewport.addEventListener("scroll", syncViewportLayoutMetrics, { passive: true });
}
window.addEventListener("beforeunload", () => {
  if (activeFriend) {
    updateLabsLastViewedForChat(getLabsChatKey(activeFriend, activeChatKind));
  }
  persistActiveMessageDraft();
  persistPendingStateNow();
});

window._novynReply = { setReply };
window._novynSocket = socket;
window._novynMe = () => me;
window._novynActiveFriend = () => activeFriend;
window._novynActiveChatKind = () => normalizeChatKind(activeChatKind);
window._novynRequestHistoryRefresh = () => {
  if (!socketAvailable || !isDashboardPage || !activeFriend) return false;
  socket.emit("get_history", { to: activeFriend, toType: normalizeChatKind(activeChatKind) });
  return true;
};
window._novynToast = showToast;
window._novynMessageWindow = {
  hasNewer: hasNewerMessages,
  showLatest: showLatestMessages,
  loadOlder: loadOlderMessages,
};
window._novynOpenSettingsPanel = () => setSettingsOpen(true);
window._novynCloseSettingsPanel = () => setSettingsOpen(false);
window._novynGetBlockedUsers = getBlockedUsersForSettings;
window._novynUpdateSession = () => {
  refreshAuthSessionSilently();
};
renderMyName();
setSidebarView("messages", { silent: true });
syncSettingsPanel();
setTimeout(applyMyAvatar, 200);

if (!socketAvailable) {
  setNetworkState("Realtime unavailable", "offline");
  showToast("Realtime client failed to load. Open Novyn from your server URL.", "error");
}

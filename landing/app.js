/**
 * Daily Sutra — Landing Page Script
 * Deterministic cycle-shuffle calendar engine, interactive simulator,
 * full bilingual (EN / 繁中) switching, and warm paper ambience.
 */

(function () {
  'use strict';

  // --- Global State ---
  let currentLang = localStorage.getItem('daily_sutra_lang') ||
    (typeof navigator !== 'undefined' && navigator.language && navigator.language.toLowerCase().startsWith('zh') ? 'zh' : 'en');
  let currentTheme = localStorage.getItem('daily_sutra_theme') || 'auto';
  
  // Simulator State
  let simDate = new Date();
  let simWarmPaper = true;
  let simFullTextOpen = false;
  let simPinned = false;
  let currentVerseIndex = null; // if set manually, overrides date

  const verses = window.SUTRA_VERSES || [];

  // --- Deterministic cycle-shuffle pick (mirrors Swift DailyPick) ---
  function cycleOrder(cycle, count) {
    let seed = BigInt.asUintN(64, BigInt(cycle));
    const next = () => {
      seed = BigInt.asUintN(64, seed + 0x9E3779B97F4A7C15n);
      let z = seed;
      z = BigInt.asUintN(64, (z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n);
      z = BigInt.asUintN(64, (z ^ (z >> 27n)) * 0x94D049BB133111EBn);
      return z ^ (z >> 31n);
    };
    const order = Array.from({ length: count }, (_, i) => i);
    for (let i = count - 1; i > 0; i--) {
      const j = Number(next() % BigInt(i + 1));
      [order[i], order[j]] = [order[j], order[i]];
    }
    return order;
  }

  function dailyPickIndex(year, month, day, totalCount) {
    if (totalCount <= 0) return 0;
    const dayNum = Math.floor(Date.UTC(year, month - 1, day) / 86400000);
    const cycle = Math.floor(dayNum / totalCount);
    const order = cycleOrder(cycle, totalCount);
    if (totalCount > 2 && order[0] === cycleOrder(cycle - 1, totalCount)[totalCount - 1]) {
      [order[0], order[1]] = [order[1], order[0]];
    }
    return order[dayNum - cycle * totalCount];
  }

  function getActiveVerse() {
    if (!verses.length) return null;
    if (currentVerseIndex !== null) {
      return verses[currentVerseIndex % verses.length];
    }
    const y = simDate.getFullYear();
    const m = simDate.getMonth() + 1;
    const d = simDate.getDate();
    const idx = dailyPickIndex(y, m, d, verses.length);
    return verses[idx];
  }

  function formatWeekday(date, lang) {
    const enDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const zhDays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    const day = date.getDay();
    return lang === 'zh' ? zhDays[day] : enDays[day];
  }

  function formatDateHeading(date, verse, lang) {
    const dayName = formatWeekday(date, lang);
    if (!verse) return dayName;
    if (verse.sutra === 'heart') {
      return lang === 'zh'
        ? `${dayName} — 心經 · 第${verse.index}段`
        : `${dayName} — Heart Sutra · ${verse.index}`;
    }
    return lang === 'zh'
      ? `${dayName} — 第${verse.index}章`
      : `${dayName} — Chapter ${verse.index}`;
  }

  // --- Render Simulator ---
  function renderSimulator() {
    const verse = getActiveVerse();
    if (!verse) return;

    const panel = document.getElementById('sutra-panel');
    const titleEl = document.getElementById('sim-panel-title');
    const dayTagEl = document.getElementById('sim-panel-day-tag');
    const quoteEl = document.getElementById('sim-quote-text');
    const explBox = document.getElementById('sim-explanation-box');
    const blessingBox = document.getElementById('sim-blessing-box');
    const blessingText = document.getElementById('sim-blessing-text');
    const blessingEmoji = document.getElementById('sim-blessing-emoji');
    const fullTextToggle = document.getElementById('sim-full-text-btn-text');
    const fullTextContent = document.getElementById('sim-full-text-content');

    // Warm Paper toggle styling
    if (simWarmPaper) {
      panel.classList.add('warm-paper');
    } else {
      panel.classList.remove('warm-paper');
    }

    const isZh = (currentLang === 'zh');
    const weekdayStr = formatWeekday(simDate, currentLang);

    // Title: Single uniform header title exactly matching native macOS app (hiding sutra name)
    titleEl.textContent = formatDateHeading(simDate, verse, currentLang);
    if (dayTagEl) {
      dayTagEl.style.display = 'none';
    }

    // In-card language toggle pill
    const simLangToggle = document.getElementById('sim-lang-toggle');
    if (simLangToggle) {
      simLangToggle.textContent = isZh ? 'EN' : '中';
    }

    // Pull-quote
    quoteEl.textContent = isZh ? verse.verseZh : `“${verse.verseEn}”`;

    // Explanation & Reflection
    const expl = isZh ? verse.explZh : verse.explEn;
    const meaning = isZh ? verse.meaningZh : verse.meaning;
    const combined = [expl, meaning].filter(Boolean).join(' ');
    explBox.innerHTML = isZh
      ? `<strong>解釋：</strong>${combined}`
      : `<strong>Explanation:</strong> ${combined}`;

    // Blessing
    const rawBlessing = isZh ? verse.blessingZh : verse.blessing;
    let renderedBlessing = rawBlessing
      ? rawBlessing.replace(/\{weekday\}/g, weekdayStr)
      : (isZh ? `願你${weekdayStr}輕安。🙏` : `May your ${weekdayStr} be light. 🙏`);

    // Extract closing emoji if present
    const emojiMatch = renderedBlessing.match(/[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]$/u);
    if (emojiMatch) {
      blessingEmoji.textContent = emojiMatch[0];
      blessingText.textContent = renderedBlessing.slice(0, -emojiMatch[0].length).trim();
    } else {
      blessingEmoji.textContent = '🪷';
      blessingText.textContent = renderedBlessing;
    }

    // Full Text
    fullTextToggle.textContent = isZh ? '完整經文與對照' : 'Full Classical Text';
    const credit = isZh ? verse.sourceZh : verse.sourceEn;
    const note = isZh ? '解說與祝福：AI 輔助撰寫，由作者審閱' : 'Paraphrase, commentary and blessings: AI-assisted, author-reviewed';
    fullTextContent.textContent = (isZh
      ? `${verse.titleZh}\n\n${verse.zh}`
      : `${verse.titleEn}\n\n${verse.en}`) + `\n\n${[credit, note].filter(Boolean).join('\n')}`;

    if (simFullTextOpen) {
      fullTextContent.classList.add('open');
    } else {
      fullTextContent.classList.remove('open');
    }
  }

  // --- Copy Formatted Verse ---
  function copySimulatorVerse() {
    const verse = getActiveVerse();
    if (!verse) return;

    const isZh = (currentLang === 'zh');
    const weekdayStr = formatWeekday(simDate, currentLang);
    const title = formatDateHeading(simDate, verse, currentLang);
    const quote = isZh ? verse.verseZh : `“${verse.verseEn}”`;
    const expl = isZh ? verse.explZh : verse.explEn;
    const meaning = isZh ? verse.meaningZh : verse.meaning;
    const combinedExpl = [expl, meaning].filter(Boolean).join(' ');
    const explParagraph = isZh ? `解釋：${combinedExpl}` : `Explanation: ${combinedExpl}`;
    const rawBlessing = isZh ? verse.blessingZh : verse.blessing;
    const blessing = rawBlessing
      ? rawBlessing.replace(/\{weekday\}/g, weekdayStr)
      : (isZh ? `願你${weekdayStr}輕安。🙏` : `May your ${weekdayStr} be light. 🙏`);

    const formattedText = `${title}\n\n${quote}\n\n${explParagraph}\n\n${blessing}`;

    navigator.clipboard.writeText(formattedText).then(() => {
      const msg = document.getElementById('sim-copy-feedback');
      msg.textContent = isZh ? '✓ 已複製到剪貼簿' : '✓ Copied to clipboard';
      msg.classList.add('show');
      setTimeout(() => msg.classList.remove('show'), 2400);
    }).catch(err => {
      console.warn('Clipboard write failed:', err);
    });
  }

  // --- Internationalization (EN / zh-TW) ---
  const I18N = {
    en: {
      site_title: 'Daily Sutra — Contemplative macOS Menu Bar App',
      brand_sub: 'macOS',
      nav_features: 'Features',
      nav_simulator: 'Live Simulator',
      nav_philosophy: 'Philosophy',
      nav_install: 'Install & FAQ',
      download_btn: 'Download v1.2.1',
      eyebrow_text: '🌸 A Contemplative macOS Companion · Open Source & 100% Offline',
      hero_title: 'Quiet wisdom for your morning desk.',
      hero_sub: 'One passage each day from the Diamond Sutra, the Heart Sutra, or both, floating quietly in your menu bar. A fixed daily pick, classical Chinese text, plain-language reflections, and zero digital noise.',
      hero_cta_download: 'Download for macOS (Free)',
      hero_cta_simulator: 'Try Live Simulator ↓',
      hero_meta_os: 'macOS 14 Sonoma or later',
      hero_meta_arch: 'Apple Silicon & Intel Universal',
      hero_meta_size: '1.8 MB · Zero Telemetry',

      sim_label: 'Interactive macOS Card Simulator',
      sim_heading: 'Experience the morning contemplation ritual right now',
      sim_today_btn: 'Today',
      sim_warm_paper_btn: 'Warm Paper',
      sim_copy_btn: 'Copy Verse (⌘C)',
      sim_note: 'Notice: This simulator runs the same date-seeded cycle shuffle as the native Mac app. Within an app version, the same calendar date always gives the same verse, and every verse appears once per cycle. This demo reads from both sutras (42 days); the app can also read from Diamond only (32) or Heart only (10).',

      preset_today: "Today's Verse",
      preset_ch1: "Ch. 1: The Ordinary Meal",
      preset_ch2: "Ch. 2: Bodhisattva Vow",
      preset_ch4: "Ch. 4: Giving Without Attachment",
      preset_ch26: "Ch. 26: The Window of Form",
      preset_heart: "Heart Sutra: Form & Emptiness",

      phil_tag: 'The Anti-Algorithm Manifesto',
      phil_title: 'Designed to ground your attention, not capture it.',
      phil_sub: 'Most software fights for your dopamine. Daily Sutra is a digital shrine: calm, quiet, predictable, and gone the moment you click away.',
      phil_card1_title: 'Deterministic Calendar Math',
      phil_card1_desc: 'No AI recommendations, no feeds, and no engagement tracking. A date-seeded shuffle picks the verse for each day, so every verse appears once per cycle (42 days with both sutras). Within an app version, the same calendar date always gives the same verse, anywhere, and tomorrow brings the next with gentle inevitability.',
      phil_card2_title: '42 Sacred Contemplations',
      phil_card2_desc: 'Curated from the 32 chapters of the Diamond Sutra and 10 contemplative movements of the Heart Sutra. Read both in one pool, or choose Diamond only or Heart only in Settings.',
      phil_card3_title: 'Bilingual Parallel Dignity',
      phil_card3_desc: 'Authentic 5th-century Kumārajīva (鳩摩羅什) classical Chinese and Xuanzang (玄奘) Heart Sutra text, accompanied by contemporary English paraphrases, plain-language explanations, and reflective commentary. Source credits sit at the foot of every Full Text view, and the English pull-quote is labeled as an AI-assisted paraphrase.',
      phil_card4_title: 'Warm Paper Reading Ambience',
      phil_card4_desc: 'Inspired by traditional Xuan paper (宣紙淡墨). Switch seamlessly between modern glass and soothing warm paper tint to soothe your eyes during early dawn or late evening reflections.',

      feat_tag: 'Built for macOS Craft',
      feat_title: 'Lightweight, respectful, and native.',
      feat_card1_title: 'Dockable or Freely Floating',
      feat_card1_desc: 'Snap directly beneath your menu bar icon with screen-edge safety margins, or drag freely across multiple desktop monitors. Origin coordinates persist seamlessly across restarts.',
      feat_card2_title: 'Pin Floating Panel',
      feat_card2_desc: 'Toggle the pin button to keep the verse floating beside your journal, code editor, or meditation space across workspace switches.',
      feat_card3_title: '1-Click Formatted Copy',
      feat_card3_desc: 'Press Cmd+C to copy verse, explanation, and personalized daily blessing directly into Obsidian, Apple Notes, Notion, or chat.',
      feat_card4_title: 'Font Scaling (0.85× to 1.8×)',
      feat_card4_desc: 'Adjust typography effortlessly for studio displays or compact laptop screens with persistent font scaling.',
      feat_card5_title: 'Native SwiftUI + AppKit',
      feat_card5_desc: 'Built purely with Swift 5.9. Zero Electron, zero webviews. Instantaneous launch, a 1.8 MB download, and 0.0% idle CPU.',
      feat_card6_title: '100% Offline & Private',
      feat_card6_desc: 'Zero analytics, zero crash telemetry, zero network requests. Your daily contemplation is entirely private between you and your machine.',

      showcase_tag: 'Gallery Showcase',
      showcase_title: 'A serene presence in your daily workflow.',
      showcase_sub: 'Built for macOS 14 Sonoma and later, with refined typography and natural AppKit panel physics.',
      showcase_tab_en: 'English Verse Card',
      showcase_tab_zh: 'Classical Chinese Card',
      showcase_tab_settings: 'Settings & Preferences',
      showcase_cap_en: 'Modern English verse, plain-language explanation, and daily blessing anchored right below the menu bar.',
      showcase_cap_zh: 'Authentic Kumārajīva & Xuanzang classical lines with modern Traditional Chinese reflections.',
      showcase_cap_settings: 'Native macOS settings sheet: choose Both, Diamond or Heart, font scaling, reading ambience (warm paper tint), and window placement docking.',

      install_tag: 'Getting Started',
      install_title: 'Install Daily Sutra in seconds.',
      install_step1_title: '1. Download Release',
      install_step1_desc: 'Download DailySutra.zip from the official GitHub Release (v1.2.1).',
      install_step2_title: '2. Move to Applications',
      install_step2_desc: 'Unzip the archive and drag DailySutra.app into your /Applications folder.',
      install_step3_title: '3. Open & Contemplate',
      install_step3_desc: 'Click the lotus icon in your menu bar. The verse panel opens instantly.',
      gatekeeper_title: 'macOS Gatekeeper Note',
      gatekeeper_desc: 'Daily Sutra is an open-source indie app. Because it is distributed outside the Mac App Store without an Apple Developer ID signature (builds are self-signed, not notarized), macOS may display an unidentified developer warning on first launch. Simply right-click DailySutra.app and select Open, or run:',

      sidebar_brew_title: 'Homebrew Cask',
      sidebar_brew_desc: 'Install in one command. The cask clears the Gatekeeper quarantine flag for you:',
      sidebar_source_title: 'Build From Source',
      sidebar_source_desc: 'Pure Swift Package Manager — no Xcode project file required:',

      faq_tag: 'Questions & Answers',
      faq_title: 'Frequently Asked Questions',
      faq_q1: 'Which sutras are included?',
      faq_a1: 'Daily Sutra contains 42 contemplative passages: all 32 chapters of the Diamond Sutra (金剛般若波羅蜜經, Kumārajīva text) and 10 contemplative verses from the Heart Sutra (般若波羅蜜多心經, Xuanzang text). By default they share one pool; the card header reads "Chapter N" or "Heart Sutra · N". In Settings, set Daily Sutra to Both, Diamond or Heart to read from just one.',
      faq_q2: 'Does Daily Sutra collect any personal data or make network calls?',
      faq_a2: 'None whatsoever. Daily Sutra is completely offline. The entire verse database is bundled within the app. There are no tracking libraries, no Google Analytics, no external API calls, and no accounts required.',
      faq_q3: 'How does the daily verse rotate?',
      faq_a3: 'Every day at midnight, the app re-rolls using a deterministic date-seeded shuffle: every verse appears once per cycle (42 days with both sutras, 32 Diamond only, 10 Heart only), in an order fixed by the cycle number. Within an app version, the same calendar date gives the same verse anywhere in the world (the date is read in your local time zone), without needing an internet connection or server.',
      faq_q4: 'Can I set an optional morning reminder?',
      faq_a4: 'Yes! Open Settings (Cmd+,) and enable Daily Notification at your preferred morning hour (e.g., 08:00 AM). Clicking the notification immediately reveals the morning verse.',
      faq_q5: 'Was AI used to make this?',
      faq_a5: 'Yes. The paraphrases, explanations, reflections and blessings were drafted with AI assistance, then reviewed and edited by the author; much of the code was too. They are interpretations, not the canonical sutra text. The bundled Chinese and English sutra texts are public domain (English: Gemmell 1912 for the Diamond Sutra, Max Müller 1894 for the Heart Sutra; Müller translated the Sanskrit, so it differs from the Chinese of Xuanzang in places).',

      footer_dedication: '“願以此功德，普及於一切。我等與眾生，皆共成佛道。”\nMay clarity, peace, and quiet presence accompany your day.',
      footer_links_product: 'Product',
      footer_links_community: 'Community & Code',
      footer_copy: '© 2026 Daily Sutra. Open source under the MIT License. Created by acchuang.'
    },

    zh: {
      site_title: 'Daily Sutra · 金剛心經每日一頌（macOS 選單列晨讀伴侶）',
      brand_sub: 'macOS 原生',
      nav_features: '功能特色',
      nav_simulator: '線上體驗',
      nav_philosophy: '設計理念',
      nav_install: '安裝與常見問題',
      download_btn: '下載 v1.2.1',
      eyebrow_text: '🌸 macOS 原生選單列小工具 · 開源 · 100% 離線無追蹤',
      hero_title: '在忙碌的工作桌面，\n留一段清淨晨光。',
      hero_sub: '每天早上在選單列打開一則金剛經或心經，也可以在設定裡只選其中一部。不靠演算法，純粹依照日期輪播；收錄鳩摩羅什與玄奘大師經典譯本，並附上白話解讀與每日祝福。',
      hero_cta_download: '免費下載 macOS 版',
      hero_cta_simulator: '直接在線上試用 ↓',
      hero_meta_os: '支援 macOS 14 Sonoma 或更新版本',
      hero_meta_arch: 'Apple Silicon 及 Intel 通用版本',
      hero_meta_size: '檔案僅 1.8 MB · 零追蹤碼',

      sim_label: 'macOS 選單列互動模擬器',
      sim_heading: '現在就能直接體驗早晨的閱讀卡片',
      sim_today_btn: '今日',
      sim_warm_paper_btn: '宣紙色溫',
      sim_copy_btn: '複製偈頌 (⌘C)',
      sim_note: '說明：這個線上模擬器和 Mac 原生 App 使用相同的日期洗牌方式。同一個 App 版本裡，同一個日期不論在哪裡讀到的經文都一樣，而且每則經文每個週期剛好出現一次。這個模擬器同時讀兩部經（42 天）；App 也可以只讀金剛經（32 天）或只讀心經（10 天）。',

      preset_today: '今日偈頌',
      preset_ch1: '第 1 章：日常著衣乞食',
      preset_ch2: '第 2 章：菩薩發願與降伏',
      preset_ch4: '第 4 章：不住相布施',
      preset_ch26: '第 26 章：若以色見我',
      preset_heart: '心經：色即是空',

      phil_tag: '設計理念',
      phil_title: '安靜退居幕後，不爭奪你的注意力。',
      phil_sub: '多數軟體都在搶你的注意力。Daily Sutra 只安靜待在選單列，點開看幾秒、滑鼠移開就收起，不跳通知、不打擾工作。',
      phil_card1_title: '按日期固定輪播，不靠演算法',
      phil_card1_desc: '沒有推薦演算法，沒有動態牆，也不會追蹤使用習慣。每天依照西元日期洗牌挑選，每則每個週期剛好出現一次（兩部皆選為 42 天），同一個 App 版本裡同一個日期不論在哪裡看到的都是同一則偈頌，明天時間一到自動換下一則。',
      phil_card2_title: '42 則經典般若篇章',
      phil_card2_desc: '精選金剛經 32 分與心經 10 段核心觀照。可兩部一起讀，也能在設定裡只選金剛經或只選心經。每天早上花一兩分鐘讀一則，不賣弄玄學，踏實沉澱。',
      phil_card3_title: '原文與白話並列',
      phil_card3_desc: '完整收錄五世紀鳩摩羅什大師譯本與七世紀玄奘大師心經原典，附上現代英譯、平實白話解釋與生活體會。每則完整經文底部都有出處標註，英文金句也會標明是 AI 輔助意譯。',
      phil_card4_title: '宣紙色溫閱讀感',
      phil_card4_desc: '開啟宣紙色溫（Warm Paper Tint），底色會換成淡淡的米黃色，清晨或深夜看螢幕比較不刺眼。',

      feat_tag: '專為 macOS 設計',
      feat_title: '乾淨、安靜、不佔系統資源。',
      feat_card1_title: '依附選單列或自由拖曳',
      feat_card1_desc: '可以固定吸附在選單列圖示正下方，也能自由拖到多螢幕的任何位置。視窗座標會自動記住，再次開啟時位置不跑掉。',
      feat_card2_title: '圖釘懸浮置頂',
      feat_card2_desc: '點一下圖釘圖示就能鎖定卡片，切換其他軟體或做筆記時，經文依然懸浮在螢幕上。',
      feat_card3_title: '一鍵排版複製',
      feat_card3_desc: '按 Cmd+C 就能把章節、原文、白話解釋與今天的祝福直接複製，方便貼到筆記或日記裡。',
      feat_card4_title: '字體自由縮放 (0.85×–1.8×)',
      feat_card4_desc: '無論是大螢幕還是 13 吋筆電，都能在設定裡調整最舒適的字體大小，設定會自動儲存。',
      feat_card5_title: '純 Swift 5.9 原生開發',
      feat_card5_desc: '純 Swift 搭配 AppKit 與 SwiftUI，不包 Electron 或 Webview。軟體大小只有 1.8 MB，平常待命時 CPU 使用率為 0.0%。',
      feat_card6_title: '100% 離線隱私',
      feat_card6_desc: '完全不用連網，沒有埋任何追蹤碼，也不需要註冊帳號。所有資料只存在你自己的電腦上。',

      showcase_tag: '真實介面呈現',
      showcase_title: '安靜融入你的 Mac 桌面。',
      showcase_sub: '針對 macOS 14 Sonoma 以上設計，外觀自動跟隨系統的深色或淺色模式。',
      showcase_tab_en: '英文晨讀卡片',
      showcase_tab_zh: '中文經文卡片',
      showcase_tab_settings: '偏好設定面板',
      showcase_cap_en: '現代英譯偈頌、白話解讀與專屬星期祝福，平時固定在選單列正下方。',
      showcase_cap_zh: '鳩摩羅什與玄奘大師經典原文，附上現代白話解讀與生活體會。',
      showcase_cap_settings: '偏好設定面板：可選兩部皆選、金剛經或心經，並自訂字體大小、切換宣紙色溫，以及調整視窗是否依附在選單列。',

      install_tag: '安裝方式',
      install_title: '三步驟直接開始使用。',
      install_step1_title: '1. 下載壓縮檔',
      install_step1_desc: '從 GitHub Releases 下載 DailySutra.zip（最新版 v1.2.1）。',
      install_step2_title: '2. 放進「應用程式」',
      install_step2_desc: '解壓縮後，把 DailySutra.app 拉到「應用程式」（/Applications）資料夾。',
      install_step3_title: '3. 點選單列圖示',
      install_step3_desc: '開啟後，頂部選單列就會出現蓮花圖示，點一下即可展開晨讀卡片。',
      gatekeeper_title: 'macOS Gatekeeper 安全提示',
      gatekeeper_desc: 'Daily Sutra 是個人開源軟體，未購買 Apple 商業開發者憑證簽章（以自簽憑證簽署，未經公證），首次打開時 macOS 可能會顯示「未識別的開發者」提示。只要在 DailySutra.app 上按右鍵選「打開」確認，或在終端機執行：',

      sidebar_brew_title: 'Homebrew 安裝',
      sidebar_brew_desc: '習慣使用終端機的話，一行指令即可安裝，並自動移除 Gatekeeper 隔離標記：',
      sidebar_source_title: '自行編譯原始碼',
      sidebar_source_desc: '純 Swift Package Manager 專案，不用安裝肥大的 Xcode：',

      faq_tag: '常見問題',
      faq_title: '你可能會想了解的事',
      faq_q1: 'App 收錄了哪些經文？',
      faq_a1: '收錄鳩摩羅什大師譯本《金剛般若波羅蜜經》全部 32 分，以及玄奘大師譯本《般若波羅蜜多心經》切出的 10 個核心觀照。預設兩部合併輪播，卡片標題顯示「第 N 章」或「心經 · 第 N 段」。也可以在設定的「每日經典」選擇兩部皆選、金剛經或心經，只讀其中一部。',
      faq_q2: 'App 會收集個人資料或連上網路嗎？',
      faq_a2: '完全不會。Daily Sutra 是 100% 離線軟體，所有經文與程式都在本機內，不依賴任何外部伺服器，更沒有任何分析追蹤碼。',
      faq_q3: '每天更換經文的原理是什麼？',
      faq_a3: '每天午夜零點，App 會依當天的西元年月日算出今天是第幾天，再用洗牌決定經文：每則每個週期剛好出現一次（兩部皆選 42 天，只選金剛經 32 天，只選心經 10 天）。同一個 App 版本裡，同一個日期在世界各地看到的都是同一首偈頌（日期以你所在時區為準）。',
      faq_q4: '可以設定晨間提醒通知嗎？',
      faq_a4: '可以。按下 Cmd+, 打開設定面板，開啟「每日定時提醒」並選擇時間（例如早上 08:00）。點一下通知就會直接展開今天的晨讀卡片。',
      faq_q5: '有用到 AI 製作嗎？',
      faq_a5: '有。白話譯寫、解說、省思與祝福語，皆由 AI 協助起草，再由作者審閱修改；程式碼也有不少部分如此。這些屬於詮釋，並非經文原典。內附的中英文經文則為公有領域（英文：金剛經採 Gemmell 1912，心經採 Max Müller 1894；Müller 譯自梵文，與玄奘漢譯略有出入）。',

      footer_dedication: '「願以此功德，普及於一切。我等與眾生，皆共成佛道。」\n願清涼智慧與平靜，伴隨你的每一天。',
      footer_links_product: '產品',
      footer_links_community: '開源社群',
      footer_copy: '© 2026 Daily Sutra. 採 MIT 授權條款開源，由 acchuang 製作。'
    }
  };

  function updatePageLanguage(lang) {
    currentLang = lang;
    localStorage.setItem('daily_sutra_lang', lang);
    document.documentElement.lang = (lang === 'zh' ? 'zh-TW' : 'en');

    // Update Language Pills in Header
    document.querySelectorAll('[data-lang-choice]').forEach(el => {
      if (el.getAttribute('data-lang-choice') === lang) {
        el.classList.add('active');
      } else {
        el.classList.remove('active');
      }
    });

    // Update text content with data-i18n
    const strings = I18N[lang];
    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.getAttribute('data-i18n');
      if (strings[key]) {
        if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
          el.value = strings[key];
        } else {
          el.textContent = strings[key];
        }
      }
    });

    renderSimulator();

    // Sync showcase view to match language
    if (typeof window.__updateShowcaseView === 'function') {
      const activeTab = document.querySelector('[data-showcase].active')?.getAttribute('data-showcase');
      if (activeTab === 'en' && lang === 'zh') {
        window.__updateShowcaseView('zh');
      } else if (activeTab === 'zh' && lang === 'en') {
        window.__updateShowcaseView('en');
      } else if (activeTab === 'settings') {
        window.__updateShowcaseView('settings');
      }
    }
  }

  // --- Theme Controller ---
  function updateTheme(theme) {
    currentTheme = theme;
    localStorage.setItem('daily_sutra_theme', theme);

    if (theme === 'dark') {
      document.documentElement.setAttribute('data-theme', 'dark');
    } else if (theme === 'light') {
      document.documentElement.removeAttribute('data-theme');
    } else {
      // auto / system
      if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        document.documentElement.setAttribute('data-theme', 'dark');
      } else {
        document.documentElement.removeAttribute('data-theme');
      }
    }
  }

  // --- Event Bindings ---
  function initEvents() {
    // Language toggles
    document.querySelectorAll('[data-lang-choice]').forEach(el => {
      el.addEventListener('click', () => {
        updatePageLanguage(el.getAttribute('data-lang-choice'));
      });
    });

    // In-card language toggle button (matches native macOS app)
    document.getElementById('sim-lang-toggle')?.addEventListener('click', () => {
      updatePageLanguage(currentLang === 'zh' ? 'en' : 'zh');
    });

    // Theme toggle button
    const themeBtn = document.getElementById('theme-toggle-btn');
    if (themeBtn) {
      themeBtn.addEventListener('click', () => {
        const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
        updateTheme(isDark ? 'light' : 'dark');
      });
    }

    // Simulator Date Navigation
    document.getElementById('sim-prev-day')?.addEventListener('click', () => {
      currentVerseIndex = null;
      simDate.setDate(simDate.getDate() - 1);
      renderSimulator();
    });

    document.getElementById('sim-next-day')?.addEventListener('click', () => {
      currentVerseIndex = null;
      simDate.setDate(simDate.getDate() + 1);
      renderSimulator();
    });

    document.getElementById('sim-today-btn')?.addEventListener('click', () => {
      currentVerseIndex = null;
      simDate = new Date();
      renderSimulator();
    });

    // Simulator Warm Paper Toggle
    document.getElementById('sim-warm-paper-toggle')?.addEventListener('click', () => {
      simWarmPaper = !simWarmPaper;
      renderSimulator();
    });

    // Simulator Copy Button
    document.getElementById('sim-copy-btn')?.addEventListener('click', copySimulatorVerse);

    // Full Text Drawer
    document.getElementById('sim-full-text-toggle')?.addEventListener('click', () => {
      simFullTextOpen = !simFullTextOpen;
      renderSimulator();
    });

    // Simulator Presets
    document.querySelectorAll('[data-preset]').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('[data-preset]').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        const preset = btn.getAttribute('data-preset');
        if (preset === 'today') {
          currentVerseIndex = null;
          simDate = new Date();
        } else if (preset === 'ch1') {
          currentVerseIndex = 0; // Diamond Ch 1
        } else if (preset === 'ch2') {
          currentVerseIndex = 1; // Diamond Ch 2
        } else if (preset === 'ch4') {
          currentVerseIndex = 3; // Diamond Ch 4
        } else if (preset === 'ch26') {
          currentVerseIndex = 25; // Diamond Ch 26
        } else if (preset === 'heart') {
          // Find first heart sutra verse
          const heartIdx = verses.findIndex(v => v.sutra === 'heart');
          currentVerseIndex = heartIdx >= 0 ? heartIdx : 32;
        }
        renderSimulator();
      });
    });

    // Showcase Gallery Tabs
    const showcaseImg = document.getElementById('showcase-main-img');
    const showcaseCaption = document.getElementById('showcase-caption');
    const showcaseData = {
      en: {
        getSrc: () => 'assets/screenshot-en.png',
        capKey: 'showcase_cap_en'
      },
      zh: {
        getSrc: () => 'assets/screenshot-zh.png',
        capKey: 'showcase_cap_zh'
      },
      settings: {
        getSrc: () => (currentLang === 'zh' ? 'assets/screenshot-settings-zh.png' : 'assets/screenshot-settings.png'),
        capKey: 'showcase_cap_settings'
      }
    };

    function updateShowcaseView(key) {
      const activeBtn = document.querySelector(`[data-showcase="${key}"]`);
      if (activeBtn) {
        document.querySelectorAll('[data-showcase]').forEach(b => {
          b.classList.remove('active');
          b.setAttribute('aria-selected', 'false');
        });
        activeBtn.classList.add('active');
        activeBtn.setAttribute('aria-selected', 'true');
      }

      const item = showcaseData[key];
      if (item && showcaseImg) {
        showcaseImg.style.opacity = '0.2';
        setTimeout(() => {
          showcaseImg.src = item.getSrc();
          showcaseImg.style.opacity = '1';
        }, 120);

        if (showcaseCaption) {
          showcaseCaption.setAttribute('data-i18n', item.capKey);
          showcaseCaption.textContent = I18N[currentLang][item.capKey] || '';
        }
      }
    }
    window.__updateShowcaseView = updateShowcaseView;

    document.querySelectorAll('[data-showcase]').forEach(btn => {
      btn.addEventListener('click', () => {
        const key = btn.getAttribute('data-showcase');
        updateShowcaseView(key);
      });
    });

    // FAQ Accordion
    document.querySelectorAll('.faq-item').forEach(item => {
      const q = item.querySelector('.faq-question');
      q?.addEventListener('click', () => {
        const isOpen = item.classList.contains('open');
        document.querySelectorAll('.faq-item').forEach(i => i.classList.remove('open'));
        if (!isOpen) {
          item.classList.add('open');
        }
      });
    });

    // Copy Code Buttons
    document.querySelectorAll('.copy-code-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const code = btn.getAttribute('data-code');
        if (code) {
          navigator.clipboard.writeText(code).then(() => {
            const original = btn.textContent;
            btn.textContent = '✓ Copied';
            setTimeout(() => { btn.textContent = original; }, 2000);
          });
        }
      });
    });

    // Global Keyboard Shortcuts
    document.addEventListener('keydown', (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

      if (e.key === 'ArrowLeft') {
        currentVerseIndex = null;
        simDate.setDate(simDate.getDate() - 1);
        renderSimulator();
      } else if (e.key === 'ArrowRight') {
        currentVerseIndex = null;
        simDate.setDate(simDate.getDate() + 1);
        renderSimulator();
      } else if (e.key === 't' || e.key === 'T') {
        currentVerseIndex = null;
        simDate = new Date();
        renderSimulator();
      } else if ((e.metaKey || e.ctrlKey) && e.key === 'c') {
        // If no text is selected on page, copy simulator verse
        if (!window.getSelection().toString()) {
          copySimulatorVerse();
        }
      }
    });

    // Listen to OS theme changes if theme is auto
    if (window.matchMedia) {
      window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
        if (localStorage.getItem('daily_sutra_theme') === 'auto') {
          updateTheme('auto');
        }
      });
    }
  }

  // --- Initialization ---
  document.addEventListener('DOMContentLoaded', () => {
    updateTheme(currentTheme);
    updatePageLanguage(currentLang);
    initEvents();
  });
})();

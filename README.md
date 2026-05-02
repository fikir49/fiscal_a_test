# Fiscal-A: Next-Gen Financial Intelligence Vault 

Fiscal-A is a high-performance, privacy-focused financial management system built with Flutter. It combines cutting-edge AI, Computer Vision, and biometric security to transform how users track, analyze, and protect their financial life.

##  Key Features

###  The Financial Vault (Security)
*   **Biometric Hardening:** Access to sensitive financial data is strictly protected via `local_auth` (Fingerprint/FaceID).
*   **Privacy-First UI:** Real-time data blurring (Glassmorphism) ensures that your balances are hidden from prying eyes until you are verified.
*   **Local Persistence:** Powered by a high-speed NoSQL Hive database. Your data never leaves your device.

###  Fiscal Buddy (AI Advisor)
*   **Context-Aware Intelligence:** Integrated with **Gemini 2.5 Flash** to provide real-time, personalized financial advice.
*   **Live Data Grounding:** The AI knows your ledger and current market rates, giving you accurate, data-driven insights.
*   **Asynchronous Streaming:** Instant responses with token-by-token text generation.

###  Computer Vision (AI Scanner)
*   **OCR Integration:** Uses **Google ML Kit** to scan physical receipts and documents.
*   **Smart Parsing:** Automatically extracts amounts and descriptions, eliminating manual data entry errors.

### 📈 Market Intelligence
*   **Real-Time Pipeline:** Live ETB/USD exchange rates and global market indices.
*   **Direct News Ticker:** Curated financial headlines from trusted global and Ethiopian sources (Addis Insight, Reuters) with direct-to-web links.

###  Predictive Analytics
*   **Burn Rate Forecasting:** Advanced time-series analysis to predict your monthly spending velocity and keep you on budget.

##  Architecture
*   **Frontend:** Flutter (Dart)
*   **Intelligence:** Google Gemini 2.5 & Google ML Kit
*   **Database:** Hive (NoSQL)
*   **State Management:** Reactive setState with local persistence synchronization.
*   **Middleware Ready:** Architected for seamless migration to Serverless (Firebase/Node.js) backends.

##  Getting Started

1.  **Build the App:**
    ```bash
    flutter pub get
    flutter build apk --release
    ```
2.  **Generate Brand Icons:**
    ```bash
    flutter pub run flutter_launcher_icons
    ```

##  License
Distributed under the MIT License. See `LICENSE` for more information.

### 📈 Market & Strategic Vision
*   **Target Audience:** Individual investors, small business owners, and students in Ethiopia's emerging digital economy.
*   **Problem Solved:** High financial fragmentation and asset-tracking opacity.
*   **Strategic Impact:** Providing "Privacy-First" banking-grade tools that operate independently of centralized servers, giving users total control over their data.

### 🏗️ Infrastructure & Scalability
*   **Current State:** Fully functional edge-device application (Local-first).
*   **Future Roadmap:** Migration to a **Distributed Serverless Middleware** (Firebase Cloud Functions) to support:
    *   Multi-device synchronization.
    *   API Key rotation and request queuing.
    *   Collaborative financial vaults.

---
**Built by Hp Zbook** - *Excellence in Financial Intelligence.*

# Fiscal-A: Next-Gen Financial Intelligence Vault

[![Flutter CI](https://github.com/fikir49/fiscal_a_test/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/fikir49/fiscal_a_test/actions/workflows/flutter_ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Fiscal-A is a high-performance, privacy-focused financial management system built with Flutter. It integrates advanced Artificial Intelligence, Computer Vision, and biometric security to provide a secure environment for tracking, analyzing, and protecting financial assets.

## Table of Contents
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Contributing](#contributing)
- [License](#license)
- [Market and Strategic Vision](#market-and-strategic-vision)
- [Infrastructure and Scalability](#infrastructure-and-scalability)

## Key Features

### Financial Vault (Security)
*   **Biometric Hardening:** Access to sensitive financial data is strictly protected via local_auth (Fingerprint/FaceID).
*   **Privacy-First UI:** Real-time data blurring (Glassmorphism) ensures that balances remain obscured until user identity is verified.
*   **Local Persistence:** Powered by a high-speed NoSQL Hive database. Data is stored locally on the device to maximize privacy.

### Fiscal Buddy (AI Advisor)
*   **Context-Aware Intelligence:** Integrated with Gemini 2.5 Flash to provide real-time, personalized financial advisory services.
*   **Live Data Grounding:** The AI engine analyzes ledger data and current market rates to deliver data-driven insights.
*   **Asynchronous Streaming:** Instantaneous responses facilitated by token-by-token text generation.

### Computer Vision (AI Scanner)
*   **OCR Integration:** Leverages Google ML Kit for high-accuracy scanning of physical receipts and financial documents.
*   **Intelligent Parsing:** Automatically extracts transaction amounts and descriptions to eliminate manual data entry errors.

### Market Intelligence
*   **Real-Time Data Pipeline:** Integration of live ETB/USD exchange rates and global market indices.
*   **Aggregated News Ticker:** Curated financial headlines from global and regional sources (e.g., Reuters, Addis Insight) with direct source links.

### Predictive Analytics
*   **Burn Rate Forecasting:** Utilizes time-series analysis of historical transactions to project spending velocity and generate proactive budget alerts.

## Architecture
*   **Frontend:** Flutter (Dart)
*   **Intelligence Layer:** Google Gemini 2.5 & Google ML Kit
*   **Data Layer:** Hive (NoSQL Key-Value Store)
*   **State Management:** Reactive State handling with synchronized local persistence.
*   **Service Layer:** Architected for seamless transition to Distributed Serverless Middleware (Firebase/Node.js).

## Getting Started

### Prerequisites
*   Flutter SDK (Stable channel)
*   Android SDK / Xcode

### Installation
1.  **Clone the repository and fetch dependencies:**
    ```bash
    flutter pub get
    ```
2.  **Generate platform-specific branding:**
    ```bash
    flutter pub run flutter_launcher_icons
    ```
3.  **Execute a Release Build:**
    ```bash
    flutter build apk --release
    ```

## Contributing
Contributions to the Fiscal-A project are welcome. 
*   Fork the repository and create a feature branch.
*   Submit Pull Requests for review.
*   Report bugs or suggest features via the [Issue Tracker](https://github.com/fikir49/fiscal_a_test/issues).

## License
Distributed under the MIT License. See `LICENSE` for further details.

## Market and Strategic Vision
*   **Target Market:** Individual investors and small-scale entrepreneurs within the emerging digital economy.
*   **Core Value Proposition:** Mitigation of financial fragmentation and data opacity.
*   **Strategic Impact:** Delivery of decentralized, "Privacy-First" financial tools that operate independently of centralized banking infrastructure.

## Infrastructure and Scalability
*   **Current Deployment:** Edge-device application (Local-first architecture).
*   **Roadmap:** Implementation of a Distributed Serverless Middleware (Firebase Cloud Functions) to facilitate multi-device synchronization and secure API request queuing.

---
**Built by Hp Zbook** - *Excellence in Financial Intelligence.*

# Mobo Event

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white)
![Odoo](https://img.shields.io/badge/Odoo-714B67?style=for-the-badge&logo=odoo&logoColor=white)
![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg?style=for-the-badge)


Mobo Event is a powerful mobile solution designed to seamlessly integrate with Odoo, empowering businesses to manage their events, registrations, and attendees with efficiency and precision. Built with Flutter, it offers a high-performance, intuitive interface for organizing events, tracking registrations, and managing tickets directly from your mobile device.

## Key Features

### Comprehensive Event Management
- **Real-Time Event Tracking**: Monitor event status, sessions, and schedules across your organization instantly.
- **Event Creation & Editing**: Create new events with detailed information including dates, venues, ticket types, and descriptions.
- **Calendar View**: Visualize events with an integrated calendar for easy scheduling and slot management.

### Registration & Attendee Management
- **Attendee Tracking**: Manage event registrations and track attendee details in real time.
- **QR Code Scanning**: Quick check-in of attendees using integrated barcode and QR code scanning.
- **Registration Forms**: Dynamic registration forms with customizable questions and answers.

### Ticket Management
- **Ticket Creation**: Create and manage multiple ticket types per event with pricing and seat limits.
- **Ticket Sales Monitoring**: Track ticket availability and sales performance.

### Communication & Scheduling
- **Email Scheduler**: Schedule and send communications to attendees directly from the app.
- **Template Management**: Use email templates for consistent attendee communication.
- **Activity Scheduling**: Schedule and manage activities within events with timeline tracking.

### Questions & Surveys
- **Event Questions**: Create and manage custom questions for event registrations.
- **Answer Tracking**: Monitor and review attendee responses and feedback.

### Security & User Experience
- **Biometric Authentication**: Secure and fast login using fingerprint or Face ID.
- **2-Factor Authentication (2FA)**: Support for Time-based One-Time Password (TOTP) for enhanced security.
- **User Access Control**: Permission-based access governed by Odoo's user group settings.
- **Switch Account**: Quickly swap between multiple Odoo accounts and databases.
- **Multi-Company Support**: Easily switch between different company profiles.
- **Dark Mode**: Fully optimized dark theme for comfortable usage.
- **Performance**: Optimized with pagination and domain-based filtering for large datasets.

## Screenshots



<div>
  <img src="assets/git/1.png" width="200" height="500" style="margin:8px;" />
  <img src="assets/git/2.png" width="200" height="500" style="margin:8px;" />
  <img src="assets/git/3.png" width="200" height="500" style="margin:8px;" />
  <img src="assets/git/4.png" width="200" height="500" style="margin:8px;" />
</div>


## Technology Stack

Mobo Event is built using modern technologies to ensure reliability and performance:

- **Frontend**: Flutter (Dart)
- **State Management**: Provider
- **Backend Integration**: Odoo RPC
- **Authentication**: Local Auth (Biometrics) & Odoo Session Management
- **Calendar**: Table Calendar for event scheduling
- **Scanning**: Mobile Scanner for QR/Barcode check-in

## Supported Odoo Versions

Tested and verified on:
- **Odoo version 17 - 19** (Community & Enterprise)

## Getting Started

### Prerequisites
- Flutter SDK (Latest Stable)
- Odoo Instance (v17 or higher recommended)
- Android Studio or VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/mobo-open-source/mobo_event.git
   cd mobo_event
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run
   ```

## Usage

To get started with Mobo Event:

1. **Open the App**: Launch Mobo Event on your mobile device.
2. **Setup Server**: Enter your Odoo server URL.
3. **Select Database**: Choose the appropriate database for your company.
4. **Login**: Enter your Odoo credentials (including 2FA if enabled).
5. **Start Managing**: Begin managing your events, registrations, and attendees efficiently.

## Roadmap

Future improvements planned for Mobo Event:
- [ ] **Offline Support**: Enable work without internet with automatic synchronization.
- [ ] **AI Support**: Intelligent event insights and optimized scheduling suggestions.
- [ ] **Push Notifications**: Real-time alerts for new registrations and event updates.

## Contributing

We welcome contributions to improve Mobo Event!
1. Fork the project.
2. Create your feature branch (`git checkout -b feature/NewFeature`).
3. Commit your changes (`git commit -m 'Add NewFeature'`).
4. Push to the branch (`git push origin feature/NewFeature`).
5. Open a Pull Request.

## Maintainers

**Team Mobo at Cybrosys Technologies**
- [mobo@cybrosys.com](mailto:mobo@cybrosys.com)

## License

This project is primarily licensed under the Apache License 2.0.
It also includes third-party components licensed under:
- MIT License
- GNU Lesser General Public License (LGPL)

See the [LICENSE](LICENSE) file for the main license and [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for details on included dependencies and their respective licenses.

Hello, I need your help with a small Flutter accounting app for small merchants. 
Here is a summary of the requirements and environment:

1️⃣ Application:
- Name: Raseed
- Type: Small accounting app (MVP)
- Platform: Flutter
- Database: SQLite (sqflite)
- 100% Offline
- Simple UI
- Targeted for small merchants to manage sales, record debts, and track balance
- UX design: simple and clear, client debt colors: green/yellow/red

2️⃣ Core Features:
- Register customers (name, phone number)
- Record transactions: cash sale, debt, payment
- Automatically calculate each customer's total debt
- Debt reminder notifications after a configurable number of days
- Open WhatsApp chat with customer from the app
- Dashboard showing: daily sales total, total debt, number of transactions
- Configurable settings: max debt, max days before reminder

3️⃣ Database:
- Tables: customers, transactions, settings
- transactions: type (cash, debt, payment), amount, customer_id, date, note
- Each debt/payment transaction automatically updates the customer's total debt
- Source of truth = transactions (total_debt computed from transactions)
- Settings: max_debt, max_days, reminder_days, whatsapp_days, strict_mode

4️⃣ Code Architecture:
- Service Layer for everything: CustomerService, TransactionService, SettingsService
- UI interacts only with services, no direct SQL queries
- Models: Customer, AppTransaction
- Standards: clean code, scalable, easy to maintain, ready for future expansion

5️⃣ Screen Analysis (UX / Navigation):
- **Dashboard:** daily summary, buttons to view customers and add quick transactions
- **Customers List:** list of all customers with current debt, button to add a new customer, tap a customer to open details
- **Customer Details:** customer info, current debt, transaction list, buttons: add debt, payment, open WhatsApp, edit customer
- **Add/Edit Customer (Dialog):** enter name and phone number, save/cancel
- **Settings:** edit max debt, max days for reminder, save/cancel
- **Optional:** Transactions Log (can be merged with customer details)

**Navigation Map:**
Dashboard
   ├─> Customers List
   │       ├─> Customer Details
   │       │       ├─> Add/Edit Customer (dialog)
   │       │       ├─> WhatsApp
   │       │       └─> Transactions Log (optional)
   │       └─> Add Customer (dialog)
   └─> Quick Add Cash / Debt / Payment (dialog)
Settings (from side menu or icon)

6️⃣ Requirements:
- Provide ready-to-use Flutter code + UI examples for each screen
- Implement functions: addDebt, addPayment, addCash, calculateTotalDebt
- Show debt reminder notifications according to settings
- Design database helpers, services, customer list UI, and customer details screen
- Ensure correct calculations when adding, editing, or deleting data
- Design a simple and user-friendly UI with customer debt color coding
- Use dialogs for small operations to reduce the number of screens

⚡ Goal:
Deliver a near-complete Flutter codebase ready to run with a local database, scalable for future expansion, supporting all basic accounting functions for small merchants.
Hello, I need your help with a small Flutter accounting app for small merchants. 
Here is a summary of the requirements and environment:

1️⃣ Application:
- Name: Raseed
- Type: Small accounting app (MVP)
- Platform: Flutter
- Database: SQLite (sqflite)
- 100% Offline
- Simple UI with modern aesthetics
- Targeted for small merchants to manage sales, record debts, and track balance
- UX design: simple and clear, client debt colors: green/yellow/red

2️⃣ Core Features:
- Register customers (name, phone number)
- **Multi-Product Sales**: Create sales with multiple items in a single transaction
- **Barcode Scanning**: Integrated camera-based scanner to quickly add products to cart
- Record transactions: cash sale, debt, payment
- **Partial Payments**: Support for splitting a sale between cash and remaining debt
- **Strict Validations**:
    - No repayment allowed for customers with zero debt
    - Repayment amount cannot exceed current total debt
    - Paid amount in sales cannot exceed total value of products
- Automatically calculate each customer's total debt
- Debt reminder notifications after a configurable number of days
- Open WhatsApp chat with customer from the app
- Dashboard showing: daily sales total, total debt, recent activity
- Configurable settings: max debt, reminder frequency, strict mode

3️⃣ Database (Version 7):
- **Tables**: customers, transactions, transaction_items, products, settings
- **customers**: `total_debt` stores current YER balance
- **transactions**: type (cash, debt, payment), amount, `paidAmount` (for partials), customer_id, date, note
- **transaction_items**: links multiple items to a transaction (product_id, quantity, unit price)
- **products**: name, price, stock_quantity, barcode
- Each transaction automatically updates the customer's total debt and product stock levels
- Source of truth = transactions (total_debt updated from transaction flow)

4️⃣ Code Architecture:
- Service Layer: CustomerService, TransactionService, SettingsService, ProductService
- UI interacts only with services (Dependency Injection via `get_it`)
- Models: Customer, AppTransaction, TransactionItem, Product
- Logic: Atomic database transactions used for multi-product sales (Transaction + Items + Stock Update)

5️⃣ Screen Analysis (UX / Navigation):
- **Dashboard:** daily summary, quick access to Sales, Customers, and Get Payment
- **Sale Screen:** full-page checkout with cart, barcode scanner, quantity controls, and partial payment support
- **Store Screen:** inventory management (Add/Edit Products with inventory tracking and barcode support)
- **Customers List:** list of all customers with current debt highlight
- **Customer Details:** customer info, current debt, full transaction history
- **Payment Dialog:** simplified quick collection for customer debts

**Navigation Map:**
Dashboard
   ├─> Sale Screen (New Sale)
   ├─> Customers List
   │       └─> Customer Details
   ├─> Store (Inventory)
   └─> Get Payment (Quick Collection)
Settings

6️⃣ Implementation Standards:
- Robust error handling for overpayments and stock shortages
- Responsive design using `flutter_screenutil`
- Internationalization support (English/Arabic)
- Atomic database operations for data consistency
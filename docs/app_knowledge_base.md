You are a senior software architect with 20+ years of experience in building accounting and POS systems.

I am building a Flutter MVP app called **Raseed**, and I need you to strictly follow the architecture and business rules below. Do NOT suggest alternative architectures unless explicitly asked.

---

# 🔥 CORE ARCHITECTURE (DO NOT CHANGE)

## 1. Debt System (CRITICAL)

* Use **Global Balance Model**
* Customer debt is NOT linked to specific invoices
* All payments reduce total customer debt directly
* Source of truth = transactions table ONLY
* `customers.total_debt` is stored but MUST always be updated via transactions

---

## 2. Transactions Rules

Supported transaction types:

* SALE
* PAYMENT
* RETURN

### SALE:

* Has multiple products (stored in transaction_items)
* Supports partial payment:
  total_amount = sum(items)
  paid_amount = user input
  remaining = total_amount - paid_amount
* Remaining amount is added to customer debt

### PAYMENT:

* Reduces customer total debt
* NOT linked to any sale

### RETURN:

* Stored as NEGATIVE transaction
* Reduces customer debt
* Restores product stock

---

## 3. IMMUTABILITY RULE (VERY IMPORTANT)

* Transactions are **immutable**
* NO editing allowed after creation
* Only allowed operation:

  * VOID (soft delete using flag)
* To fix mistakes: create reverse transaction

---

## 4. STOCK RULES

* Stock is updated ONLY through transactions
* Sale → decrease stock
* Return → increase stock
* Prevent selling if stock is insufficient (based on settings)

---

## 5. PRICING RULE

* Product price is copied into transaction_items at time of sale
* Future changes to product price must NOT affect old transactions

---

## 6. DEBT LIMIT

* Configurable:

  * BLOCK → prevent sale
  * WARNING → allow with alert

---

# 🧱 DATABASE DESIGN (FINAL - DO NOT BREAK)

Tables:

## customers

* id (PK)
* name
* phone
* total_debt

## products

* id (PK)
* name
* price
* stock_quantity
* barcode

## transactions

* id (PK)
* type (sale, payment, return)
* amount
* paid_amount
* customer_id (nullable)
* date
* note
* is_void (0/1)

## transaction_items

* id (PK)
* transaction_id
* product_id
* quantity
* unit_price

## settings

* id (PK)
* max_debt
* debt_mode (block / warning)
* reminder_days
* strict_stock (0/1)

---

# ⚙️ SERVICE LAYER RULES

* UI must NOT access database directly

Use:

* CustomerService

* TransactionService

* ProductService

* SettingsService

* Use dependency injection (get_it)

---

# 🔒 VALIDATION RULES

You MUST enforce:

* Cannot pay if customer debt = 0
* Payment cannot exceed total debt
* Paid amount in sale ≤ total amount
* Cannot sell if stock < required (if strict mode ON)
* Cannot exceed max debt (based on mode)

---

# ⚡ TRANSACTION FLOW (ATOMIC)

For SALE:

1. Insert transaction
2. Insert transaction_items
3. Update stock
4. Update customer total_debt

ALL inside ONE SQLite transaction

---

# 🚀 PERFORMANCE & SCALABILITY RULES (CRITICAL)

## INDEXING (REQUIRED)

* Add indexes for:

  * transactions.customer_id
  * transactions.date
  * transaction_items.transaction_id
  * products.barcode

## PAGINATION (MANDATORY)

* NEVER load all transactions at once
* Use pagination for:

  * customer transactions
  * dashboard history

## DERIVED DATA RULE

* NEVER calculate debt by summing transactions on every query
* Use stored `total_debt` for performance
* Transactions remain source of truth for corrections

## VOID LOGIC

* When transaction is voided:

  * Reverse its effects:

    * restore stock
    * restore customer debt
* DO NOT physically delete records

## CONCURRENCY SAFETY

* All write operations MUST use SQLite transactions
* Prevent partial updates

## BARCODE PERFORMANCE

* Use indexed exact match (no LIKE)

## FUTURE SAAS READINESS

* Design tables so `user_id` can be added later
* Avoid hardcoding single-user assumptions

## ERROR HANDLING

* All service methods must return:

  * success / failure
  * clear error message (not raw exception)

## LOGGING (DEBUG MODE)

* Log:

  * sale creation
  * payments
  * returns

## CLEAN CODE RULE

* Each method = one responsibility
* Avoid large functions (>50 lines)

---

# 🚀 NEW FEATURES IMPLEMENTED (V1.0 - V1.28)

## 1. Advanced Product Inventory
* **Multi-Unit System**: Support for Main Unit (e.g., Box) and Sub Unit (e.g., Piece) with a conversion factor.
* **Product Categorization**: Products belong to specific categories.
* **Pricing Tiers**: Added `wholesale_price` and `cost_price` to products.
* **Inventory Management**: Added `reorder_level` for low-stock warnings and `shelf_location` for physical organization.

## 2. Batch & Expiry Management
* **Product Batches**: Stock is now tracked via the `product_batches` table, allowing each batch to have its own quantity, cost price, and `expiry_date`.
* **Proactive Expiry Alerts**: System automatically identifies products expiring within 30 days and displays visual alerts on the Dashboard and Product List.

## 3. Customer Analytics
* **Total Spent Tracking**: Customers now have a `total_spent` metric updated via transactions.
* **Customer Segmentation**: Configurable thresholds (`vip_threshold`, `inactive_days`, `dead_days`) to categorize customers based on their purchasing behavior.

## 4. Communication & Receipts
* **WhatsApp Integration**: Option to automatically send WhatsApp notifications to customers upon payment or debt addition (`enable_whatsapp`).
* **PDF Receipts**: Support for generating and sharing PDF receipts (`enable_pdf_receipt`).

## 5. Kiosk Mode & POS UX
* **Smart POS Header**: Replaces summary cards with a sleek, action-oriented header for Kiosk environments.
* **Undo Last Sale**: Quick access "Undo" button to reverse the last transaction instantly.
* **Long-press to Void**: Advanced transaction management in activity lists.

## 6. Security & Developer Control
* **Developer Mode**: Hidden portal (7 taps on Settings Title + PIN `8899`) to manage sensitive configurations.
* **Feature Gating**: All premium actions (Sell, Edit, Export, Payments) are strictly gated by `SubscriptionService`.
* **Proactive Subscription Status**: Home screen displays real-time trial status and "Trial Expired" alerts with direct WhatsApp contact for activation.
* **Module Sequestration**: "Subscription" and "Module Management" settings are visible ONLY in Developer Mode.

## 7. Accounting Hub & Financial Ledger
* **Double-Entry Foundation**: Implementation of `accounts`, `journal_entries`, and `journal_entry_lines` for professional bookkeeping.
* **Chart of Accounts**: Pre-configured accounts for Assets (Cash, Inventory, AR), Liabilities (AP), Revenue, and Expenses.
* **Expense Management**: Dedicated module to track business expenses with category-based organization and ledger integration.

## 8. Supplier & Procurement Management
* **Supplier Lifecycle**: Full registry for suppliers with debt tracking and transaction history.
* **Procurement Workflow**: Purchase orders and supplier transactions that automatically update inventory and accounts payable.
* **Supplier-Product Linkage**: Associate products with preferred suppliers for streamlined reordering.

## 9. Shift Management & Staff Security
* **Multi-Role Access Control**: Defined roles (Admin, Cashier, Warehouse) to restrict access to sensitive financial data.
* **Shift Reconciliation**: Tracking of opening/closing balances with "System vs Actual" cash reporting to prevent leaks.
* **User-Specific Tracking**: All transactions are tagged with the active user and shift ID for audit trails.

## 10. Advanced Reporting & Exports
* **Document Generation**: Professional PDF and Excel exports for Sales, Expenses, and Profit/Loss reports.
* **Interactive Dashboard**: Statistical cards are interactive, allowing one-tap filtering of transactions (e.g., overdue rents, pending payments).
* **Thermal Printer Support**: Integrated printing for 58mm/80mm POS receipts.

## 11. Cloud & Data Integrity
* **Google Drive Backup**: Seamless integration for backing up and restoring the SQLite database to the user's cloud storage.
* **Automated Local Backups**: Regular snapshots of the database to prevent data loss.

## 12. Premium Visual Identity
* **Custom Typography**: Standardized on `Cairo-Black.ttf` for a high-end, Arabic-optimized user experience.
* **Responsive Kiosk Design**: UI components optimized for both handheld mobile and large tablet/POS displays.
* **Adaptive Product Entry**: "Quick vs Advanced" UI toggle to balance ease of use with professional accounting detail.

---

# 🎯 UX REQUIREMENTS

* Fast workflow (optimized for busy shops)
* Cart-based sales screen
* Barcode scanner support
* Minimal clicks
* Arabic + English support

---

# 🚫 IMPORTANT

* Do NOT introduce complex patterns
* Do NOT use over-engineered architecture
* Keep code simple, readable, production-ready
* Prefer clarity over abstraction

---

# ✅ YOUR TASK

When I ask for code:

* Generate production-ready Flutter + SQLite (sqflite)
* Follow ALL rules strictly
* Keep code modular and clean
* Do NOT change database structure unless I ask

---

Now wait for my next request.

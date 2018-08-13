# Architecture

models
  products
  past_price_record
    belongs_to products

The main core shall be a module PriceTracker that grabs the latest values for the
products and merges them in. This will in turn, be called from a cron_job via Quantum



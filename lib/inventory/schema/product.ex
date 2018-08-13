defmodule Inventory.Schema.Product do
  use Ecto.Schema
  import Ecto.Changeset


  schema "products" do
    field :external_product_id, :integer
    field :price, :integer
    field :product_name, :string

    has_many :past_price_records, Inventory.Schema.PastPriceRecord

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:external_product_id, :product_name, :price])
    |> validate_required([:external_product_id, :product_name, :price])
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> unique_constraint(:external_product_id)
  end
end

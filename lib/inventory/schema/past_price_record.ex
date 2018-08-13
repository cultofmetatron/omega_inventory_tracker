defmodule Inventory.Schema.PastPriceRecord do
  use Ecto.Schema
  import Ecto.Changeset


  schema "past_price_records" do
    field :percentage_change, :float
    field :price, :integer
    #field :product_id, :id
    belongs_to :product, Inventory.Schema.Product

    timestamps()
  end

  @doc false
  def changeset(past_price_record, attrs) do
    past_price_record
    |> cast(attrs, [:price, :percentage_change])
    |> validate_required([:price, :percentage_change])
  end
end

defmodule Inventory.PriceTracker do
  @moduledoc """
  PriceTracker is the set of code that fetches data for products
  and merges or creates the records in the database
  """
  import Logger
  alias Inventory.Repo
  alias Ecto.Changeset
  alias Inventory.Schema.Product
  alias Inventory.Schema.PastPriceRecord

  @time_format "{ISO:Extended}"


  @doc"""
    performs the actual work of pulling down objects and udpating our database with the infornation
  """
  def update_products(url, api_key, start_date, end_date) do
    case fetch_records(url, api_key, start_date, end_date) do
      {:error, msg} ->
        Logger.error msg
      products when is_list(products) ->
        merge_record_changes(products)
    end
  end

  @doc """
  fetches the records and returns a list of responses
  url: the url to be called
  api_key: a string api key
  start_date: a timex record
  end_date: a timex record
%HTTPotion.Response{body: body, status_code: 200}
  """
  def fetch_records(url, api_key, start_date, end_date) do
    with {:ok, start_date} <- format_time(start_date),
          {:ok, end_date} <- format_time(end_date),
          #{:ok, request_url} <- generate_get_string(url, api_key, start_date, end_date),
          %HTTPotion.Response{body: body, status_code: 200}  <- HTTPotion.get(url, query: %{
            api_key: api_key,
            start_date: start_date,
            end_date: end_date
          }),
          {:ok, records} <- parse_body(body)
    do
      {:ok, records}
    else
      {:error, val} -> {:error, val}
      %HTTPotion.Response{body: _, headers: _, status_code: _} -> {:error, :invalid_http_response} #todo: change this later based on what api returns
    end
  end

  @doc """
  takes the body and parses it into a string
  """
  def parse_body(body) do
    with {:ok, records} <- Poison.Parser.parse(body)
    do
      records = records
        |> Map.get("productRecords")
        |> Enum.map(&process_record/1)
      {:ok, records}
    else
      {:error, error, _} -> {:error, error}
      error -> error
    end
  end


  @doc """
    takes the value as a string "$30.23" and returns the integer value in cents :: 3023
  """
  def process_price("$" <> price) do
    process_price(price)
  end
  def process_price(price) when is_binary(price) do
    #split the price into the left and right of '.'
    [dollars, cents] = price
      |> String.split(".")
      |> Enum.map(fn(num) ->
        {number, ""} = Integer.parse(num, 10) #should raise if a different number arises
        number
      end)
    dollars * 100 + cents #return value in cents
  end

  def process_record(%{ "id" => id, "name" => name, "price" => price, "discontinued" => discontinued? }) do
    %{
      external_product_id: id,
      product_name: name,
      price: process_price(price),
      discontinued?: discontinued?
    }
  end

  @doc """
    generates a string with the required query paramaters
  """
  def generate_get_string(url, api_key, start_date, end_date) do
    {:ok, "#{url}?api_key=#{api_key}&start_date=#{start_date}&end_date=#{end_date}"}
  end


  def format_time(timex_record) do
    timex_record
      |> Timex.format(@time_format)
  end


  def merge_record_changes(records) when is_list(records) do
    records
      |> Enum.map(&merge_record_change/1)
  end

  # merge the data structures
  @doc"""
    Design Brief

  """
  def merge_record_change(%{ external_product_id: external_product_id, product_name: _product_name, price: _price } = record) do
    case Repo.get_by(Product, external_product_id: external_product_id ) do
      nil ->
        create_product(record)
      product ->
        update_product(product, record)
    end
  end

  @doc"""
    If there is not an existing product with a matching external_product_id and the product is not discontinued,
    create a new product record for it.
    Explicitly log that there is a new product and that you are creating a new product.
  """
  def create_product(%{ external_product_id: external_product_id, product_name: _product_name, price: _price } = record) do
    case %Product{}
      |> Product.changeset(record)
      |> Repo.insert() do
        {:error, _changeset} ->
          msg = "Failure to create product external_id: #{external_product_id}"
          Logger.error msg
          {:error, msg}
        {:ok, product} ->
          Logger.info "Product created with id: #{product.id}"
          {:ok, product}
      end
  end

  @doc"""
  * If there's an existing product with an external_product_id that matches the id of a product in the response,
    it has the same name and the price differs,
    create a new past price record for the product.
    Then update the product's price. Do this even if the item is discontinued.
  """
  def update_product(%Product{ external_product_id: external_product_id, product_name: product_name } = product, %{ external_product_id: external_product_id, product_name: product_name, price: price }) do
    if product.price !== price do
      percentage_change = (price - product.price) / price

      Repo.transaction(fn ->
        #insert a past price record
        with { :ok, past_price_record } <- product
            |> Ecto.build_assoc(:past_price_records)
            |> PastPriceRecord.changeset(%{ percentage_change: percentage_change, price: product.price })
            |> Repo.insert(),
          { :ok, product } <- product
            |> Product.changeset(%{})
            |> Changeset.put_change(:price, price)
            |> Repo.update()
        do
          product
        else
          {:error, _changeset } ->
            #TODO: expose the changeset error to the user
            Logger.error "an error upadting product #{product.id} occurred"
            Repo.rollback(:product_update_error)
          _ ->
            Logger.error "an error upadting product #{product.id} occurred"
            Repo.rollback(:product_update_error)
        end
      end)
    end
  end

  @doc"""
      * If there is an existing product record with a matching external_product_id, but a different product name,
      log an error message that warns the team that there is a mismatch.
      Do not update the price.
  """
  def update_product(%Product{ external_product_id: external_product_id, id: id  } = product, %{ external_product_id: external_product_id, product_name: product_name }) do
    msg = "product id:#{id} with external id: #{external_product_id} name does not match :: #{product.product_name} !== #{product_name}"
    Logger.warn msg
    { :error, msg}
  end

  def update_product(product, _) do
    msg = "Unknown error updating product #{product.id}"
    Logger.error msg
    {:error, msg}
  end

end

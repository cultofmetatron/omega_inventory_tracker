defmodule Inventory.PriceTracker do
  @moduledoc """
  PriceTracker is the set of code that fetches data for products
  and merges or creates the records in the database
  """

  @time_format "{ISO:Extended}"

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

end

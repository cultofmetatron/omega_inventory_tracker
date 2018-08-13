defmodule Inventory.PriceTrackerTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock

  use InventoryWeb.ConnCase
  alias Inventory.PriceTracker

  @date_format "{ISO:Extended}"

  @url_endpoint "https://omegapricinginc.com/pricing/records.json"
  @api_key "SF934-DKFJ3-S3CR3T-K3Y"
  #now
  @date1 "2018-08-13T01:09:59.469017+00:00"

  #one month ago
  @date2 "2018-07-13T01:10:36.387155+00:00"

  #two months ago
  @date3 "2018-06-13T01:11:07.639609+00:00"

  setup do
    ExVCR.Config.cassette_library_dir("../../fixtures/playback_cassettes", "./test/fixtures")
    :ok
  end


  test "process_price returns cents" do
    assert 3332 == PriceTracker.process_price("$33.32")
    assert 3332 == PriceTracker.process_price("33.32")
    assert 234_325 == PriceTracker.process_price("2343.25")
    assert 234_325 == PriceTracker.process_price("$2343.25")
  end

  test "get_url returns appropriate type response" do
    {:ok, get_url} = PriceTracker.generate_get_string(
      @url_endpoint,
      @api_key,
      @date2,
      @date1)

    assert get_url == "https://omegapricinginc.com/pricing/records.json?api_key=SF934-DKFJ3-S3CR3T-K3Y&start_date=2018-07-13T01:10:36.387155+00:00&end_date=2018-08-13T01:09:59.469017+00:00"

  end


  test "fetch records returns a cleaned list" do
    {:ok, start_date } = @date2 |> Timex.parse(@date_format)
    {:ok, end_date } = @date1 |> Timex.parse(@date_format)
    use_cassette "omega_cassettes", custom: true do
      HTTPotion.start

      {:ok, records } = PriceTracker.fetch_records(
        @url_endpoint,
        @api_key,
        start_date,
        end_date)

    end

  end



end

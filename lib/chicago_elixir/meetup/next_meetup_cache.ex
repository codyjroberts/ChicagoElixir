defmodule ChicagoElixir.Meetup.NextMeetupCache do
  use GenServer

  alias ChicagoElixir.Meetup.Api

  @interval 1 * 60 * 60 * 1000 # every hour
  @time_format "{WDshort} {M}/{D} {h12}:{m}{am}"

  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    unless Mix.env == :test do
      fetch()
    end

    {:ok, state}
  end

  def fetch() do
    GenServer.cast(__MODULE__, :fetch)
  end

  def next_meetup() do
    GenServer.call(__MODULE__, :next_meetup)
  end

  defp schedule_fetch() do
    Process.send_after(self(), {:"$gen_cast", :fetch}, @interval)
  end

  # server

  def handle_cast(:fetch, _state) do
    schedule_fetch()
    data = Api.get!("events").body
    {:noreply, data}
  end

  def handle_call(:next_meetup, _from, []), do: {:reply, nil, []}
  def handle_call(:next_meetup, _from, state) do
    [next_meetup|_] = state

    meetup = %{
      time: meetup_time(next_meetup),
      title: next_meetup["name"],
      description: meetup_description(next_meetup),
      url: next_meetup["link"],
    }

    {:reply, meetup, state}
  end

  defp meetup_description(meetup) do
    HtmlSanitizeEx.basic_html(meetup["description"])
  end

  defp meetup_time(meetup) do
    time = meetup["time"]

    local_time = time
                 |> Timex.from_unix(:millisecond)
                 |> Timex.Timezone.convert("America/Chicago")


    formatted = Timex.format!(local_time, @time_format)
    relative = Timex.format!(local_time, "{relative}", :relative)
    "#{formatted} (#{relative})"
  end
end

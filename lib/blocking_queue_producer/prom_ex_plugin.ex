defmodule BlockingQueueProducer.PromExPlugin do
  @moduledoc """
  Prometheus metrics for BlockingQueueProducer
  """
  use PromEx.Plugin

  @impl true
  def event_metrics(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    metric_prefix =
      Keyword.get(opts, :metric_prefix, PromEx.metric_prefix(otp_app, :blocking_queue_producer))

    Event.build(
      :blocking_queue_producer_events_metrics,
      [
        sum(
          metric_prefix ++ [:blocking_queue_producer, :events, :dispatched, :sum],
          event_name: [:blocking_queue_producer, :events, :dispatched],
          description: "Total number of dispatched events",
          measurement: :count,
          tags: [:name, :when]
        )
      ]
    )
  end

  @impl true
  def polling_metrics(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    metric_prefix =
      Keyword.get(opts, :metric_prefix, PromEx.metric_prefix(otp_app, :blocking_queue_producer))

    poll_rate = Keyword.get(opts, :poll_rate, 5_000)
    producers = Keyword.fetch!(opts, :producers)

    # Queue length details
    Polling.build(
      :blocking_queue_producer_polling_metrics,
      poll_rate,
      {__MODULE__, :execute_polling_metrics, [producers]},
      [
        last_value(
          metric_prefix ++ [:blocking_queue_producer, :queue, :length, :count],
          event_name: [:blocking_queue_producer, :queue, :length],
          description: "Number of undispatched events in a queue",
          measurement: :count,
          tags: [:name]
        )
      ]
    )
  end

  def execute_polling_metrics(producers) when is_function(producers) do
    producers.()
    |> Enum.each(fn server ->
      queue_length = BlockingQueueProducer.queue_length(server)

      :telemetry.execute([:blocking_queue_producer, :queue, :length], %{count: queue_length}, %{
        name: to_string(server)
      })
    end)
  catch
    # Broadway may be not started yet
    :exit, {:noproc, _} ->
      :ok
  end
end

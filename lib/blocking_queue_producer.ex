defmodule BlockingQueueProducer do
  use GenStage

  ## API

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: opts[:name])
  end

  @spec push(GenServer.server(), any(), non_neg_integer()) :: :ok
  def push(name, event, timeout \\ 5000) do
    GenStage.call(name, {:add_event, event}, timeout)
  end

  @spec queue_length(GenServer.server()) :: non_neg_integer()
  def queue_length(name) do
    GenStage.call(name, :queue_length)
  end

  ## Engine

  defmodule State do
    defstruct [
      :name,
      :queue,
      :max_queue_length,
      :pending_demand,
      :waiters
    ]

    def new(opts, name) do
      %State{
        name: name,
        queue: :queue.new(),
        max_queue_length: Keyword.fetch!(opts, :max_queue_length),
        pending_demand: 0,
        waiters: []
      }
    end
  end

  @impl GenStage
  def init(opts) do
    Process.flag(:trap_exit, true)
    name = (Process.info(self())[:registered_name] || self()) |> to_string()
    {:producer, State.new(opts, name)}
  end

  @impl GenStage
  def handle_call({:add_event, event}, from, %State{} = state) do
    queue = :queue.in(event, state.queue)

    case :queue.len(queue) do
      len when len > state.max_queue_length ->
        {:noreply, [], %{state | queue: queue, waiters: [from | state.waiters]}}

      _len ->
        {events, queue, demand} = dispatch_events(queue, state.pending_demand, [])

        :telemetry.execute(
          [:blocking_queue_producer, :events, :dispatched],
          %{count: state.pending_demand - demand},
          %{name: state.name, when: "add_event"}
        )

        {:reply, :ok, events, %{state | queue: queue, pending_demand: demand}}
    end
  end

  @impl GenStage
  def handle_call(:queue_length, _from, %State{} = state) do
    {:reply, :queue.len(state.queue), [], state}
  end

  @impl GenStage
  def handle_demand(incoming_demand, %State{} = state) do
    pending_demand = incoming_demand + state.pending_demand

    {events, queue, demand} =
      dispatch_events(state.queue, pending_demand, [])

    state =
      if Enum.any?(state.waiters) do
        num_to_release = max(state.max_queue_length - :queue.len(queue), 0)

        {to_release, waiters} =
          state.waiters
          |> Enum.filter(&Process.alive?/1)
          |> Enum.reverse()
          |> Enum.split(num_to_release)

        Enum.each(to_release, &GenStage.reply(&1, :ok))

        %{state | queue: queue, pending_demand: demand, waiters: Enum.reverse(waiters)}
      else
        %{state | queue: queue, pending_demand: demand}
      end

    :telemetry.execute(
      [:blocking_queue_producer, :events, :dispatched],
      %{count: pending_demand - demand},
      %{name: state.name, when: "handle_demand"}
    )

    {:noreply, events, state}
  end

  defp dispatch_events(queue, 0, events) do
    {Enum.reverse(events), queue, 0}
  end

  defp dispatch_events(queue, demand, events) do
    case :queue.out(queue) do
      {{:value, event}, queue} ->
        dispatch_events(queue, demand - 1, [event | events])

      {:empty, queue} ->
        {Enum.reverse(events), queue, demand}
    end
  end
end

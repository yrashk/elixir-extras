use Extra.Record

defrecord RecordTest.Override, a: 0 do

  def new, do: new([a: 100])

  def new(opts) do
      opts = Keyword.put opts, :a, opts[:a] * 5
      super(opts)
  end

  def a(value, r) do
    super({value, :erlang.now}, r)
  end
  def a(r) do
    {v, _} = super(r)
    v
  end
  def update_a(fun, r) do
    r.a(fun.(r.a))
  end
  def prepend_a(_, r) do
    r.a(r.a)
  end
  def merge_a(_, r) do
    r.a(r.a)
  end
  def increment_a(_, r) do
      r
  end

  def raw_a(r), do: elem(r, 2)
end

defmodule Extra.Record.Test do
  use ExUnit.Case

  test :overridable do
    record = RecordTest.Override.new
    assert record.raw_a == 500
    record = record.a(1)
    assert {1, _} = record.raw_a
    assert record.a == 1
    record = record.update_a(fn(_) -> 2 end)
    assert {2, _} = record.raw_a
    assert record.a == 2
    record = record.prepend_a(100)
    assert {2, _} = record.raw_a
    assert record.a == 2
    record = record.merge_a(100)
    assert {2, _} = record.raw_a
    assert record.a == 2
    record = record.increment_a(1)
    assert {2, _} = record.raw_a
    assert record.a == 2
  end

end
defmodule Extra.Module.Test do
  use ExUnit.Case

  test "testing split without arguments" do
    module = Very.Long.Path.To.Actual.Implementation
    assert module = Module.concat(Extra.Module.split_name(module))
  end

  test "testing split from begining of module name" do
    module = Very.Long.Path.To.Actual.Implementation
    assert {Very, Long.Path.To.Actual.Implementation} =
      Extra.Module.split_name(module, 1)
    assert {Very.Long.Path.To, Actual.Implementation} =
      Extra.Module.split_name(module, 4)
  end

  test "testing split from begining of name when pos is greater than length" do
    module = Very.Long.Path.To.Actual.Implementation
    assert {Very.Long.Path.To.Actual.Implementation, :""} =
      Extra.Module.split_name(module, 8)
  end

  test "testing split from end of module name" do
    module = Very.Long.Path.To.Actual.Implementation
    assert {Very.Long.Path.To.Actual, Implementation} =
      Extra.Module.split_name(module, -1)
    assert {Very.Long, Path.To.Actual.Implementation} =
      Extra.Module.split_name(module, -4)
  end

  test "testing split from end of name when pos is greater than length" do
    module = Very.Long.Path.To.Actual.Implementation
    assert {:"", Very.Long.Path.To.Actual.Implementation} =
      Extra.Module.split_name(module, -8)
  end

end

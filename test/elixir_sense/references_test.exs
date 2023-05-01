defmodule ElixirSense.Providers.ReferencesTest do
  use ExUnit.Case, async: true
  alias ElixirSense.Core.References.Tracer

  setup_all do
    {:ok, _} = Tracer.start_link()

    Code.compiler_options(
      tracers: [Tracer],
      ignore_module_conflict: true,
      parser_options: [columns: true]
    )

    Code.compile_file("./test/support/modules_with_references.ex")
    Code.compile_file("./test/support/module_with_builtin_type_shadowing.ex")
    Code.compile_file("./test/support/subscriber.ex")

    trace = Tracer.get()

    %{trace: trace}
  end

  test "finds reference to local function shadowing builtin type", %{trace: trace} do
    buffer = """
    defmodule B.Callee do
      def fun() do
        #  ^
        :ok
      end
      def my_fun() do
        :ok
      end
    end
    """

    references = ElixirSense.references(buffer, 2, 8, trace)

    assert [
             %{
               range: range_1,
               uri: "test/support/module_with_builtin_type_shadowing.ex"
             }
           ] = references

    assert range_1 == %{start: %{column: 14, line: 4}, end: %{column: 17, line: 4}}
  end

  test "find references with cursor over a function call", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee1.func()
        #                                                     ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 59, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             }
           ] = references

    assert range_1 == %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}}
    assert range_2 == %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}}
    assert range_3 == %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}}
  end

  test "find references with cursor over a function definition", %{trace: trace} do
    buffer = """
    defmodule ElixirSense.Providers.ReferencesTest.Modules.Callee1 do
      def func() do
        #    ^
        IO.puts ""
      end
      def func(par1) do
        #    ^
        IO.puts par1
      end
    end
    """

    references = ElixirSense.references(buffer, 2, 10, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             }
           ] = references

    assert range_1 == %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}}
    assert range_2 == %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}}
    assert range_3 == %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}}

    references = ElixirSense.references(buffer, 6, 10, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             }
           ] = references

    assert range_1 == %{start: %{line: 42, column: 60}, end: %{line: 42, column: 64}}
    assert range_2 == %{start: %{line: 65, column: 79}, end: %{line: 65, column: 83}}
  end

  test "find references with cursor over a function definition with default arg", %{trace: trace} do
    buffer = """
    defmodule ElixirSenseExample.Subscription do
      def check(resource, models, user, opts \\\\ []) do
        IO.inspect({resource, models, user, opts})
      end
    end
    """

    references = ElixirSense.references(buffer, 2, 10, trace)

    assert [
             %{
               range: range_1,
               uri: "test/support/subscriber.ex"
             },
             %{
               range: range_2,
               uri: "test/support/subscriber.ex"
             }
           ] = references

    assert range_1 == %{end: %{column: 42, line: 3}, start: %{column: 37, line: 3}}
    assert range_2 == %{end: %{column: 42, line: 4}, start: %{column: 37, line: 4}}
  end

  test "find references with cursor over a function with arity 1", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee1.func("test")
        #                                                     ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 59, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             }
           ] = references

    assert range_1 == %{start: %{line: 42, column: 60}, end: %{line: 42, column: 64}}
    assert range_2 == %{start: %{line: 65, column: 79}, end: %{line: 65, column: 83}}
  end

  test "find references with cursor over a function called via @attr.call", %{trace: trace} do
    buffer = """
    defmodule Caller do
      @attr ElixirSense.Providers.ReferencesTest.Modules.Callee1
      def func() do
        @attr.func("test")
        #      ^
      end
    end
    """

    references = ElixirSense.references(buffer, 4, 12, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             }
           ] = references

    assert range_1 == %{start: %{line: 42, column: 60}, end: %{line: 42, column: 64}}
    assert range_2 == %{start: %{line: 65, column: 79}, end: %{line: 65, column: 83}}
  end

  test "find references to function called via @attr.call", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee7.func_noarg()
        #                                                     ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 59, trace)

    assert [
             %{
               range: range_1,
               uri: "test/support/modules_with_references.ex"
             }
           ] = references

    assert range_1 == %{end: %{column: 23, line: 114}, start: %{column: 13, line: 114}}
  end

  test "find references with cursor over a function with arity 1 called via pipe operator", %{
    trace: trace
  } do
    buffer = """
    defmodule Caller do
      def func() do
        "test"
        |> ElixirSense.Providers.ReferencesTest.Modules.Callee4.func_arg()
        #                                                        ^
      end
    end
    """

    references = ElixirSense.references(buffer, 4, 62, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 == %{start: %{line: 49, column: 63}, end: %{line: 49, column: 71}}
  end

  test "find references with cursor over a function with arity 1 captured", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        Task.start(&ElixirSense.Providers.ReferencesTest.Modules.Callee4.func_arg/1)
        #                                                                  ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 72, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 == %{start: %{line: 49, column: 63}, end: %{line: 49, column: 71}}
  end

  test "find references with cursor over a function when caller uses pipe operator", %{
    trace: trace
  } do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee4.func_arg("test")
        #                                                     ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 59, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 == %{start: %{line: 49, column: 63}, end: %{line: 49, column: 71}}
  end

  test "find references with cursor over a function when caller uses capture operator", %{
    trace: trace
  } do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee4.func_no_arg()
        #                                                     ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 59, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range
             }
           ] = references

    if Version.match?(System.version(), ">= 1.14.0-rc.0") do
      # before 1.14 tracer reports invalid positions for captures
      # https://github.com/elixir-lang/elixir/issues/12023
      assert range == %{start: %{line: 55, column: 72}, end: %{line: 55, column: 83}}
    end
  end

  test "find references with cursor over a function with deault argument when caller uses default arguments",
       %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg()
        ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg("test")
        #                                                     ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 59, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 == %{start: %{line: 90, column: 60}, end: %{line: 90, column: 68}}

    references = ElixirSense.references(buffer, 4, 59, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 == %{start: %{line: 90, column: 60}, end: %{line: 90, column: 68}}
  end

  test "find references with cursor over a function with deault argument when caller does not uses default arguments",
       %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg1("test")
        ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg1()
        #                                                     ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 59, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 == %{start: %{line: 91, column: 60}, end: %{line: 91, column: 69}}

    references = ElixirSense.references(buffer, 4, 59, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             }
           ] = references

    assert range_1 == %{start: %{line: 91, column: 60}, end: %{line: 91, column: 69}}
  end

  test "find references with cursor over a module with funs with deault argument", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg1("test")
        #                                                 ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 55, trace)

    assert [
             %{
               range: range_1,
               uri: "test/support/modules_with_references.ex"
             },
             %{
               range: range_2,
               uri: "test/support/modules_with_references.ex"
             }
           ] = references

    assert range_1 == %{end: %{column: 68, line: 90}, start: %{column: 60, line: 90}}
    assert range_2 == %{end: %{column: 69, line: 91}, start: %{column: 60, line: 91}}
  end

  test "find references with cursor over a module with 1.2 alias syntax", %{trace: trace} do
    buffer = """
    defmodule Caller do
      alias ElixirSense.Providers.ReferencesTest.Modules.Callee5
      alias ElixirSense.Providers.ReferencesTest.Modules.{Callee5}
    end
    """

    references_1 = ElixirSense.references(buffer, 2, 57, trace)
    references_2 = ElixirSense.references(buffer, 3, 58, trace)

    assert references_1 == references_2
    assert [_, _] = references_1
  end

  test "find references with cursor over a function call from an aliased module", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def my() do
        alias ElixirSense.Providers.ReferencesTest.Modules.Callee1, as: C
        C.func()
        #  ^
      end
    end
    """

    references = ElixirSense.references(buffer, 4, 8, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             }
           ] = references

    assert range_1 == %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}}
    assert range_2 == %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}}
    assert range_3 == %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}}
  end

  test "find references with cursor over a function call from an imported module", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def my() do
        import ElixirSense.Providers.ReferencesTest.Modules.Callee1
        func()
        #^
      end
    end
    """

    references = ElixirSense.references(buffer, 4, 6, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             }
           ] = references

    assert range_1 == %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}}
    assert range_2 == %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}}
    assert range_3 == %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}}
  end

  test "find references with cursor over a function call pipe from an imported module", %{
    trace: trace
  } do
    buffer = """
    defmodule Caller do
      def my() do
        import ElixirSense.Providers.ReferencesTest.Modules.Callee1
        "" |> func
        #      ^
      end
    end
    """

    references = ElixirSense.references(buffer, 4, 12, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             }
           ] = references

    assert range_1 == %{start: %{line: 42, column: 60}, end: %{line: 42, column: 64}}
    assert range_2 == %{start: %{line: 65, column: 79}, end: %{line: 65, column: 83}}
  end

  test "find references with cursor over a function capture from an imported module", %{
    trace: trace
  } do
    buffer = """
    defmodule Caller do
      def my() do
        import ElixirSense.Providers.ReferencesTest.Modules.Callee1
        &func/0
        # ^
      end
    end
    """

    references = ElixirSense.references(buffer, 4, 7, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             }
           ] = references

    assert range_1 == %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}}
    assert range_2 == %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}}
    assert range_3 == %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}}
  end

  test "find imported references", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee3.func()
        #                                                     ^
      end
    end
    """

    reference = ElixirSense.references(buffer, 3, 59, trace) |> Enum.at(0)

    assert reference == %{
             uri: "test/support/modules_with_references.ex",
             range: %{start: %{line: 65, column: 47}, end: %{line: 65, column: 51}}
           }
  end

  test "find references from remote calls with the function in the next line", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee3.func()
        #                                                     ^
      end
    end
    """

    reference = ElixirSense.references(buffer, 3, 59, trace) |> Enum.at(1)

    assert %{
             uri: "test/support/modules_with_references.ex",
             range: range_1
           } = reference

    assert range_1 == %{start: %{line: 70, column: 9}, end: %{line: 70, column: 13}}
  end

  @tag requires_elixir_1_14: true
  test "find references when module with __MODULE__ special form", %{trace: trace} do
    buffer = """
    defmodule ElixirSense.Providers.ReferencesTest.Modules do
      def func() do
        __MODULE__.Callee3.func()
        #                   ^
      end
    end
    """

    reference = ElixirSense.references(buffer, 3, 25, trace) |> Enum.at(0)

    assert reference == %{
             uri: "test/support/modules_with_references.ex",
             range: %{start: %{line: 65, column: 47}, end: %{line: 65, column: 51}}
           }
  end

  test "find references of variables", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def func do
        var1 = 1
        var2 = 2
        var1 = 3
        IO.puts(var1 + var2)
      end
      def func4(ppp) do

      end
    end
    """

    references = ElixirSense.references(buffer, 6, 13, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 5, column: 5}, end: %{line: 5, column: 9}}},
             %{uri: nil, range: %{start: %{line: 6, column: 13}, end: %{line: 6, column: 17}}}
           ]

    references = ElixirSense.references(buffer, 3, 6, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 9}}}
           ]
  end

  test "find reference for variable split across lines", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def func do
        var1 =
          1
        var1
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 6, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 9}}},
             %{uri: nil, range: %{start: %{line: 5, column: 5}, end: %{line: 5, column: 9}}}
           ]
  end

  test "find references of variables in arguments", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def call(conn) do
        if true do
          conn
        end
      end
    end
    """

    references = ElixirSense.references(buffer, 2, 13, trace)

    assert references == [
             %{range: %{end: %{column: 16, line: 2}, start: %{column: 12, line: 2}}, uri: nil},
             %{range: %{end: %{column: 11, line: 4}, start: %{column: 7, line: 4}}, uri: nil}
           ]
  end

  test "find references for a redefined variable", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def my_fun(var) do
        var = 1 + var

        var
      end
    end
    """

    # `var` defined in the function header
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 14}, end: %{line: 2, column: 17}}},
      %{uri: nil, range: %{start: %{line: 3, column: 15}, end: %{line: 3, column: 18}}}
    ]

    assert ElixirSense.references(buffer, 2, 14, trace) == expected_references
    assert ElixirSense.references(buffer, 3, 15, trace) == expected_references

    # `var` redefined in the function body
    expected_references = [
      %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 8}}},
      %{uri: nil, range: %{start: %{line: 5, column: 5}, end: %{line: 5, column: 8}}}
    ]

    assert ElixirSense.references(buffer, 3, 5, trace) == expected_references
    assert ElixirSense.references(buffer, 5, 5, trace) == expected_references
  end

  test "find references for a variable in a guard", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def my_fun(var) when is_atom(var) do
        case var do
          var when var > 0 -> var
        end

        Enum.map([1, 2], fn x when x > 0 -> x end)
      end
    end
    """

    # `var` defined in the function header
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 14}, end: %{line: 2, column: 17}}},
      %{uri: nil, range: %{start: %{line: 2, column: 32}, end: %{line: 2, column: 35}}},
      %{uri: nil, range: %{start: %{line: 3, column: 10}, end: %{line: 3, column: 13}}}
    ]

    assert ElixirSense.references(buffer, 2, 14, trace) == expected_references
    assert ElixirSense.references(buffer, 2, 32, trace) == expected_references
    assert ElixirSense.references(buffer, 3, 10, trace) == expected_references

    # `var` defined in the case clause
    expected_references = [
      %{uri: nil, range: %{start: %{line: 4, column: 7}, end: %{line: 4, column: 10}}},
      %{uri: nil, range: %{start: %{line: 4, column: 16}, end: %{line: 4, column: 19}}},
      %{uri: nil, range: %{start: %{line: 4, column: 27}, end: %{line: 4, column: 30}}}
    ]

    assert ElixirSense.references(buffer, 4, 7, trace) == expected_references
    assert ElixirSense.references(buffer, 4, 16, trace) == expected_references
    assert ElixirSense.references(buffer, 4, 27, trace) == expected_references

    # `x`
    expected_references = [
      %{uri: nil, range: %{start: %{line: 7, column: 25}, end: %{line: 7, column: 26}}},
      %{uri: nil, range: %{start: %{line: 7, column: 32}, end: %{line: 7, column: 33}}},
      %{uri: nil, range: %{start: %{line: 7, column: 41}, end: %{line: 7, column: 42}}}
    ]

    assert ElixirSense.references(buffer, 7, 25, trace) == expected_references
    assert ElixirSense.references(buffer, 7, 32, trace) == expected_references
    assert ElixirSense.references(buffer, 7, 41, trace) == expected_references
  end

  test "find references for variable in inner scopes", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def my_fun([h | t]) do
        sum = h + my_fun(t)

        if h > sum do
          h + sum
        else
          h = my_fun(t) + sum
          h
        end
      end
    end
    """

    # `h` from the function header
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 15}, end: %{line: 2, column: 16}}},
      %{uri: nil, range: %{start: %{line: 3, column: 11}, end: %{line: 3, column: 12}}},
      %{uri: nil, range: %{start: %{line: 5, column: 8}, end: %{line: 5, column: 9}}},
      %{uri: nil, range: %{start: %{line: 6, column: 7}, end: %{line: 6, column: 8}}}
    ]

    Enum.each([{2, 15}, {3, 11}, {5, 8}, {6, 7}], fn {line, column} ->
      assert ElixirSense.references(buffer, line, column, trace) == expected_references
    end)

    # `h` from the if-else scope
    expected_references = [
      %{uri: nil, range: %{start: %{line: 8, column: 7}, end: %{line: 8, column: 8}}},
      %{uri: nil, range: %{start: %{line: 9, column: 7}, end: %{line: 9, column: 8}}}
    ]

    assert ElixirSense.references(buffer, 8, 7, trace) == expected_references
    assert ElixirSense.references(buffer, 9, 7, trace) == expected_references

    # `sum`
    expected_references = [
      %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 8}}},
      %{uri: nil, range: %{start: %{line: 5, column: 12}, end: %{line: 5, column: 15}}},
      %{uri: nil, range: %{start: %{line: 6, column: 11}, end: %{line: 6, column: 14}}},
      %{uri: nil, range: %{start: %{line: 8, column: 23}, end: %{line: 8, column: 26}}}
    ]

    Enum.each([{3, 5}, {5, 12}, {6, 11}, {8, 23}], fn {line, column} ->
      assert ElixirSense.references(buffer, line, column, trace) == expected_references
    end)
  end

  test "find references for variable from the scope of an anonymous function", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def my_fun(x, y) do
        x = Enum.map(x, fn x -> x + y end)
      end
    end
    """

    # `x` from the `my_fun` function header
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 14}, end: %{line: 2, column: 15}}},
      %{uri: nil, range: %{start: %{line: 3, column: 18}, end: %{line: 3, column: 19}}}
    ]

    assert ElixirSense.references(buffer, 2, 14, trace) == expected_references
    assert ElixirSense.references(buffer, 3, 18, trace) == expected_references

    # `y` from the `my_fun` function header
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 17}, end: %{line: 2, column: 18}}},
      %{uri: nil, range: %{start: %{line: 3, column: 33}, end: %{line: 3, column: 34}}}
    ]

    assert ElixirSense.references(buffer, 2, 17, trace) == expected_references
    assert ElixirSense.references(buffer, 3, 33, trace) == expected_references

    # `x` from the anonymous function
    expected_references = [
      %{uri: nil, range: %{start: %{line: 3, column: 24}, end: %{line: 3, column: 25}}},
      %{uri: nil, range: %{start: %{line: 3, column: 29}, end: %{line: 3, column: 30}}}
    ]

    assert ElixirSense.references(buffer, 3, 24, trace) == expected_references
    assert ElixirSense.references(buffer, 3, 29, trace) == expected_references

    # redefined `x`
    expected_references = [
      %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 6}}}
    ]

    assert ElixirSense.references(buffer, 3, 5, trace) == expected_references
  end

  test "find references of a variable when using pin operator", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def my_fun(a, b) do
        case a do
          ^b -> b
          %{b: ^b} = a -> b
        end
      end
    end
    """

    # `b`
    expected_references = [
      %{uri: nil, range: %{start: %{line: 2, column: 17}, end: %{line: 2, column: 18}}},
      %{uri: nil, range: %{start: %{line: 4, column: 8}, end: %{line: 4, column: 9}}},
      %{uri: nil, range: %{start: %{line: 4, column: 13}, end: %{line: 4, column: 14}}},
      %{uri: nil, range: %{start: %{line: 5, column: 13}, end: %{line: 5, column: 14}}},
      %{uri: nil, range: %{start: %{line: 5, column: 23}, end: %{line: 5, column: 24}}}
    ]

    assert ElixirSense.references(buffer, 2, 17, trace) == expected_references
    assert ElixirSense.references(buffer, 4, 8, trace) == expected_references
    assert ElixirSense.references(buffer, 4, 13, trace) == expected_references
    assert ElixirSense.references(buffer, 5, 13, trace) == expected_references
    assert ElixirSense.references(buffer, 5, 23, trace) == expected_references

    # `a` redefined in a case clause
    expected_references = [
      %{uri: nil, range: %{start: %{line: 5, column: 18}, end: %{line: 5, column: 19}}}
    ]

    assert ElixirSense.references(buffer, 5, 18, trace) == expected_references
  end

  test "find references of attributes", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      @attr "abc"
      def fun do
        @attr
      end
    end
    """

    references = ElixirSense.references(buffer, 4, 7, trace)

    assert references == [
             %{range: %{end: %{column: 8, line: 2}, start: %{column: 3, line: 2}}, uri: nil},
             %{range: %{end: %{column: 10, line: 4}, start: %{column: 5, line: 4}}, uri: nil}
           ]

    references = ElixirSense.references(buffer, 2, 4, trace)

    assert references == [
             %{range: %{end: %{column: 8, line: 2}, start: %{column: 3, line: 2}}, uri: nil},
             %{range: %{end: %{column: 10, line: 4}, start: %{column: 5, line: 4}}, uri: nil}
           ]
  end

  test "find references of private functions from definition", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def calls_private do
        private_fun()
      end

      defp also_calls_private do
        private_fun()
      end

      defp private_fun do
        #     ^
        :ok
      end
    end
    """

    references = ElixirSense.references(buffer, 10, 15, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 16}}},
             %{uri: nil, range: %{start: %{line: 7, column: 5}, end: %{line: 7, column: 16}}}
           ]
  end

  test "find references of private functions from invocation", %{trace: trace} do
    buffer = """
    defmodule MyModule do
      def calls_private do
        private_fun()
        #     ^
      end

      defp also_calls_private do
        private_fun()
      end

      defp private_fun do
        :ok
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 15, trace)

    assert references == [
             %{uri: nil, range: %{start: %{line: 3, column: 5}, end: %{line: 3, column: 16}}},
             %{uri: nil, range: %{start: %{line: 8, column: 5}, end: %{line: 8, column: 16}}}
           ]
  end

  test "find references with cursor over a module", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee1.func()
        #                                               ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 53, trace)

    assert [
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_1
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_2
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_3
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_4
             },
             %{
               uri: "test/support/modules_with_references.ex",
               range: range_5
             }
           ] = references

    assert range_1 == %{start: %{line: 36, column: 60}, end: %{line: 36, column: 64}}
    assert range_2 == %{start: %{line: 42, column: 60}, end: %{line: 42, column: 64}}
    assert range_3 == %{start: %{line: 65, column: 16}, end: %{line: 65, column: 20}}
    assert range_4 == %{start: %{line: 65, column: 63}, end: %{line: 65, column: 67}}
    assert range_5 == %{start: %{line: 65, column: 79}, end: %{line: 65, column: 83}}
  end

  test "find references with cursor over an erlang module", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        :ets.new(:s, [])
        # ^
      end
    end
    """

    references =
      ElixirSense.references(buffer, 3, 7, trace)
      |> Enum.filter(&(&1.uri =~ "modules_with_references"))

    assert [
             %{
               range: range_1,
               uri: "test/support/modules_with_references.ex"
             }
           ] = references

    assert range_1 == %{start: %{column: 12, line: 74}, end: %{column: 15, line: 74}}
  end

  test "find references with cursor over an erlang function call", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        :ets.new(:s, [])
        #     ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 11, trace)

    assert [
             %{
               range: range_1,
               uri: "test/support/modules_with_references.ex"
             }
           ] = references

    assert range_1 == %{start: %{column: 12, line: 74}, end: %{column: 15, line: 74}}
  end

  test "find references with cursor over builtin function call", %{trace: trace} do
    buffer = """
    defmodule Caller do
      def func() do
        ElixirSense.Providers.ReferencesTest.Modules.Callee6.module_info()
        #                                                      ^
      end
    end
    """

    references = ElixirSense.references(buffer, 3, 60, trace)

    assert [
             %{
               range: range_1,
               uri: "test/support/modules_with_references.ex"
             }
           ] = references

    assert range_1 == %{start: %{column: 60, line: 101}, end: %{column: 71, line: 101}}
  end
end

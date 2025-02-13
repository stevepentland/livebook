defmodule Livebook.Notebook.Export.Elixir do
  alias Livebook.Notebook
  alias Livebook.Notebook.Cell

  @doc """
  Converts the given notebook into a Elixir source code.
  """
  @spec notebook_to_elixir(Notebook.t()) :: String.t()
  def notebook_to_elixir(notebook) do
    iodata = render_notebook(notebook)
    # Add trailing newline
    IO.iodata_to_binary([iodata, "\n"])
  end

  defp render_notebook(notebook) do
    %{setup_section: %{cells: [setup_cell]} = setup_section} = notebook

    prelude = "# Run as: iex --dot-iex path/to/notebook.exs"

    name = ["# Title: ", notebook.name]
    setup_cell = render_setup_cell(setup_cell, setup_section)
    sections = Enum.map(notebook.sections, &render_section(&1, notebook))

    [prelude, name, setup_cell | sections]
    |> Enum.reject(&is_nil/1)
    |> Enum.intersperse("\n\n")
  end

  defp render_section(section, notebook) do
    name = ["# ── ", section.name, " ──"]

    name =
      if section.parent_id do
        {:ok, parent} = Notebook.fetch_section(notebook, section.parent_id)
        [name, " (⎇ from ", parent.name, ")"]
      else
        name
      end

    cells =
      section.cells
      |> Enum.map(&render_cell(&1, section))
      |> Enum.reject(&(&1 in ["", []]))

    [name | cells]
    |> Enum.intersperse("\n\n")
  end

  defp render_setup_cell(%{source: ""}, _section), do: nil
  defp render_setup_cell(cell, section), do: render_cell(cell, section)

  defp render_cell(%Cell.Markdown{} = cell, _section) do
    cell.source
    |> Livebook.LiveMarkdown.MarkdownHelpers.reformat()
    |> String.split("\n")
    |> Enum.map_intersperse("\n", &comment_out/1)
  end

  defp render_cell(%Cell.Code{language: :elixir} = cell, section) do
    if section.parent_id do
      cell.source
      |> String.split("\n")
      |> Enum.map_intersperse("\n", &comment_out/1)
    else
      cell.source
    end
  end

  defp render_cell(%Cell.Code{} = cell, _section) do
    code = cell.source

    code
    |> String.split("\n")
    |> Enum.map_intersperse("\n", &comment_out/1)
  end

  defp render_cell(%Cell.Smart{} = cell, ctx) do
    render_cell(%{Cell.Code.new() | source: cell.source}, ctx)
  end

  defp render_cell(_cell, _section), do: []

  defp comment_out(""), do: ""
  defp comment_out(line), do: ["# ", line]
end

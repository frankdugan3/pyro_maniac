defmodule PyroManiac.KanBan.PostgresExtension do
  @moduledoc """
  AshPostgres custom extension that installs the `pyro_fractional_key_between`
  PL/pgSQL function for atomic kanban card ordering.
  """

  use AshPostgres.CustomExtension,
    name: "pyro_kanban",
    latest_version: 1

  @base_digits "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

  @impl true
  def install(0) do
    Enum.map_join(sql_functions(), "\n\n", fn {_name, sql} ->
      "execute(#{inspect(sql)})"
    end)
  end

  @impl true
  def uninstall(_version) do
    sql_functions()
    |> Enum.reverse()
    |> Enum.map_join("\n", fn {name, _sql} ->
      ~s[execute("DROP FUNCTION IF EXISTS #{name}")]
    end)
  end

  defp sql_functions do
    [
      {"pyro_fi_get_integer_part(text)", get_integer_part()},
      {"pyro_fi_smallest_integer()", smallest_integer()},
      {"pyro_fi_largest_integer()", largest_integer()},
      {"pyro_fi_increment_integer(text)", increment_integer()},
      {"pyro_fi_decrement_integer(text)", decrement_integer()},
      {"pyro_fi_midpoint(text, text, text, int)", midpoint()},
      {"pyro_fractional_key_between(text, text)", main_function()},
      {"pyro_kanban_compute_rank(text, text, text, text, text, text, text)",
       compute_rank_function()}
    ]
  end

  defp get_integer_part do
    """
    CREATE OR REPLACE FUNCTION pyro_fi_get_integer_part(key text)
    RETURNS text LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $fn$
    DECLARE head int; int_len int;
    BEGIN
      head := ascii(substring(key FROM 1 FOR 1));
      IF head >= ascii('a') AND head <= ascii('z') THEN int_len := head - ascii('a') + 2;
      ELSIF head >= ascii('A') AND head <= ascii('Z') THEN int_len := ascii('Z') - head + 2;
      ELSE RAISE EXCEPTION 'invalid key head: %', chr(head);
      END IF;
      RETURN substring(key FROM 1 FOR int_len);
    END; $fn$
    """
  end

  defp smallest_integer do
    "CREATE OR REPLACE FUNCTION pyro_fi_smallest_integer() RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $fn$ SELECT 'A' || repeat('0', 26); $fn$"
  end

  defp largest_integer do
    "CREATE OR REPLACE FUNCTION pyro_fi_largest_integer() RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $fn$ SELECT 'z' || repeat('z', 26); $fn$"
  end

  defp increment_integer do
    bd = @base_digits

    """
    CREATE OR REPLACE FUNCTION pyro_fi_increment_integer(x text)
    RETURNS text LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $fn$
    DECLARE
      bd text := '#{bd}';
      base int := 62; head int; digits text; i int; val int; new_head int; new_len int;
    BEGIN
      IF x = pyro_fi_largest_integer() THEN RETURN NULL; END IF;
      head := ascii(substring(x FROM 1 FOR 1));
      digits := substring(x FROM 2);
      FOR i IN REVERSE length(digits)..1 LOOP
        val := position(substring(digits FROM i FOR 1) IN bd) - 1;
        IF val + 1 < base THEN
          RETURN chr(head) || substring(digits FROM 1 FOR i-1) || substring(bd FROM val+2 FOR 1) || substring(digits FROM i+1);
        END IF;
        digits := substring(digits FROM 1 FOR i-1) || '0' || substring(digits FROM i+1);
      END LOOP;
      IF head = ascii('Z') THEN RETURN 'a0'; END IF;
      IF head < ascii('z') THEN
        new_head := head + 1;
        IF new_head >= ascii('a') THEN new_len := new_head - ascii('a') + 2;
        ELSE new_len := ascii('Z') - new_head + 2; END IF;
        RETURN chr(new_head) || repeat('0', new_len - 1);
      END IF;
      RETURN NULL;
    END; $fn$
    """
  end

  defp decrement_integer do
    bd = @base_digits

    """
    CREATE OR REPLACE FUNCTION pyro_fi_decrement_integer(x text)
    RETURNS text LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $fn$
    DECLARE
      bd text := '#{bd}';
      base int := 62; head int; digits text; i int; val int; new_head int; new_len int;
    BEGIN
      IF x = pyro_fi_smallest_integer() THEN RETURN NULL; END IF;
      head := ascii(substring(x FROM 1 FOR 1));
      digits := substring(x FROM 2);
      FOR i IN REVERSE length(digits)..1 LOOP
        val := position(substring(digits FROM i FOR 1) IN bd) - 1;
        IF val - 1 >= 0 THEN
          RETURN chr(head) || substring(digits FROM 1 FOR i-1) || substring(bd FROM val FOR 1) || substring(digits FROM i+1);
        END IF;
        digits := substring(digits FROM 1 FOR i-1) || substring(bd FROM base FOR 1) || substring(digits FROM i+1);
      END LOOP;
      IF head = ascii('a') THEN RETURN 'Z' || repeat(substring(bd FROM base FOR 1), ascii('Z') - ascii('Z') + 1); END IF;
      IF head > ascii('A') THEN
        new_head := head - 1;
        IF new_head >= ascii('a') THEN new_len := new_head - ascii('a') + 2;
        ELSE new_len := ascii('Z') - new_head + 2; END IF;
        RETURN chr(new_head) || repeat(substring(bd FROM base FOR 1), new_len - 1);
      END IF;
      RETURN NULL;
    END; $fn$
    """
  end

  defp midpoint do
    """
    CREATE OR REPLACE FUNCTION pyro_fi_midpoint(a text, b text, bd text, base int)
    RETURNS text LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $fn$
    DECLARE
      pos int := 1; max_len int; a_val int; b_val int; mid int; result text := '';
    BEGIN
      max_len := greatest(coalesce(length(a), 0), coalesce(length(b), 0)) + 1;
      LOOP
        IF pos > max_len + 10 THEN RAISE EXCEPTION 'midpoint overflow'; END IF;
        IF pos <= coalesce(length(a), 0) THEN a_val := position(substring(a FROM pos FOR 1) IN bd) - 1;
        ELSE a_val := 0; END IF;
        IF b IS NULL THEN b_val := base;
        ELSIF pos <= length(b) THEN b_val := position(substring(b FROM pos FOR 1) IN bd) - 1;
        ELSE b_val := 0; END IF;
        IF a_val = b_val THEN
          result := result || substring(bd FROM a_val+1 FOR 1); pos := pos + 1; CONTINUE;
        END IF;
        IF b_val - a_val > 1 THEN
          mid := (a_val + b_val) / 2;
          RETURN result || substring(bd FROM mid+1 FOR 1);
        END IF;
        result := result || substring(bd FROM a_val+1 FOR 1);
        b := NULL; pos := pos + 1;
      END LOOP;
    END; $fn$
    """
  end

  defp main_function do
    bd = @base_digits

    """
    CREATE OR REPLACE FUNCTION pyro_fractional_key_between(prev text, next text)
    RETURNS text LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $fn$
    DECLARE
      ia text; ib text; fa text; fb text; incremented text;
    BEGIN
      IF prev IS NULL AND next IS NULL THEN RETURN 'a0'; END IF;

      IF prev IS NULL THEN
        ia := pyro_fi_get_integer_part(next);
        fb := substring(next FROM length(ia) + 1);
        IF ia > pyro_fi_smallest_integer() THEN RETURN pyro_fi_decrement_integer(ia);
        ELSE RETURN ia || pyro_fi_midpoint('', fb, '#{bd}', 62);
        END IF;
      END IF;

      IF next IS NULL THEN
        ia := pyro_fi_get_integer_part(prev);
        fa := substring(prev FROM length(ia) + 1);
        incremented := pyro_fi_increment_integer(ia);
        IF incremented IS NOT NULL THEN RETURN incremented;
        ELSE RETURN ia || fa || substring('#{bd}' FROM 32 FOR 1);
        END IF;
      END IF;

      IF prev >= next THEN
        RAISE EXCEPTION 'prev must be less than next';
      END IF;

      ia := pyro_fi_get_integer_part(prev);
      fa := substring(prev FROM length(ia) + 1);
      ib := pyro_fi_get_integer_part(next);
      fb := substring(next FROM length(ib) + 1);

      IF ia = ib THEN
        RETURN ia || pyro_fi_midpoint(fa, fb, '#{bd}', 62);
      END IF;

      incremented := pyro_fi_increment_integer(ia);
      IF incremented IS NOT NULL AND incremented < next THEN RETURN incremented; END IF;

      RETURN ia || pyro_fi_midpoint(fa, NULL, '#{bd}', 62);
    END; $fn$
    """
  end

  defp compute_rank_function do
    """
    CREATE OR REPLACE FUNCTION pyro_kanban_compute_rank(
      p_table text,
      p_lane_col text,
      p_priority_col text,
      p_lane_value text,
      p_record_id text,
      p_target_id text,
      p_position text
    )
    RETURNS text LANGUAGE plpgsql STABLE PARALLEL SAFE AS $fn$
    DECLARE
      prev_rank text;
      next_rank text;
      target_rank text;
    BEGIN
      IF p_position = 'last' OR p_target_id IS NULL THEN
        EXECUTE format(
          'SELECT %I FROM %I WHERE %I = $1 AND id != $2::uuid ORDER BY %I COLLATE "C" DESC LIMIT 1',
          p_priority_col, p_table, p_lane_col, p_priority_col
        ) INTO prev_rank USING p_lane_value, p_record_id;
        RETURN pyro_fractional_key_between(prev_rank, NULL);
      END IF;

      EXECUTE format('SELECT %I FROM %I WHERE id = $1::uuid', p_priority_col, p_table)
        INTO target_rank USING p_target_id;

      IF p_position = 'before' THEN
        EXECUTE format(
          'SELECT %I FROM %I WHERE %I = $1 AND id != $2::uuid AND %I COLLATE "C" < $3 ORDER BY %I COLLATE "C" DESC LIMIT 1',
          p_priority_col, p_table, p_lane_col, p_priority_col, p_priority_col
        ) INTO prev_rank USING p_lane_value, p_record_id, target_rank;
        RETURN pyro_fractional_key_between(prev_rank, target_rank);
      END IF;

      IF p_position = 'after' THEN
        EXECUTE format(
          'SELECT %I FROM %I WHERE %I = $1 AND id != $2::uuid AND %I COLLATE "C" > $3 ORDER BY %I COLLATE "C" ASC LIMIT 1',
          p_priority_col, p_table, p_lane_col, p_priority_col, p_priority_col
        ) INTO next_rank USING p_lane_value, p_record_id, target_rank;
        RETURN pyro_fractional_key_between(target_rank, next_rank);
      END IF;

      RETURN pyro_fractional_key_between(NULL, NULL);
    END; $fn$
    """
  end
end

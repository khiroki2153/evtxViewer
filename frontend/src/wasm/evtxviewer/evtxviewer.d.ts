import type * as MoonBit from "./moonbit.d.ts";

export function row_to_csv_json(columns_json: MoonBit.String,
                                row_json: MoonBit.String): MoonBit.String;

export function query_events_json(rows_json: MoonBit.String,
                                  query_json: MoonBit.String): MoonBit.String;

export function parse_csv_records(csv_text: MoonBit.String): MoonBit.String;

export function parse_evtx_records(records_json: MoonBit.String): MoonBit.String;

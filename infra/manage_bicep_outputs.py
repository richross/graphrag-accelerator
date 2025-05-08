import argparse
import json
import shlex
import sys


def save_outputs(json_string, output_file):
    """Saves the Bicep JSON output string to a file."""
    try:
        # Validate if it's a JSON string (optional, as Bicep should provide valid JSON)
        # json.loads(json_string)
        with open(output_file, "w") as f:
            f.write(json_string)
        print(f"Bicep outputs successfully saved to {output_file}", file=sys.stderr)
    except Exception as e:
        print(f"Error saving Bicep outputs: {e}", file=sys.stderr)
        sys.exit(1)


def load_outputs_as_env_vars(input_file):
    """Loads Bicep outputs from a file and prints them as shell export commands."""
    try:
        with open(input_file, "r") as f:
            outputs = json.load(f)

        for key, val_obj in outputs.items():
            if isinstance(val_obj, dict) and "value" in val_obj:
                value = val_obj["value"]
                # Sanitize key for environment variable: use uppercase and prefix
                env_var_name = f"OWNER_OUTPUT_{key.upper()}"
                # Ensure value is a string for shlex.quote
                if not isinstance(value, str):
                    value_str = json.dumps(
                        value
                    )  # For non-string values, dump as JSON string
                else:
                    value_str = value
                print(f"export {env_var_name}={shlex.quote(value_str)}")
            else:
                # Handle cases where output format might be different or a simple key-value
                value = val_obj
                env_var_name = f"OWNER_OUTPUT_{key.upper()}"
                if not isinstance(value, str):
                    value_str = json.dumps(value)
                else:
                    value_str = value
                print(f"export {env_var_name}={shlex.quote(value_str)}")

    except FileNotFoundError:
        print(f"Error: Output file {input_file} not found.", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: Could not decode JSON from {input_file}.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error loading Bicep outputs: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Manage Bicep deployment outputs.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Save command
    save_parser = subparsers.add_parser("save", help="Save Bicep outputs to a file.")
    save_parser.add_argument("json_data", help="The JSON string of Bicep outputs.")
    save_parser.add_argument("output_file", help="The file path to save outputs to.")

    # Load-env command
    load_env_parser = subparsers.add_parser(
        "load-env", help="Load Bicep outputs and print as environment variables."
    )
    load_env_parser.add_argument(
        "input_file", help="The file path to load outputs from."
    )

    args = parser.parse_args()

    if args.command == "save":
        save_outputs(args.json_data, args.output_file)
    elif args.command == "load-env":
        load_outputs_as_env_vars(args.input_file)

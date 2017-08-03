defmodule KNXnetIP.Frame.Tunnelling do
  @moduledoc """
  Implementation of the KNXnet/IP Tunnelling specification (document 3/8/4)
  """

  alias KNXnetIP.Frame.Core

  @tunnel_linklayer 0x02

  def constant(:tunnel_linklayer), do: @tunnel_linklayer
  def constant(@tunnel_linklayer), do: :tunnel_linklayer
  def constant(_), do: nil

  defmodule TunnellingRequest do
    defstruct communication_channel_id: nil,
      sequence_counter: nil,
      telegram: <<>>
  end

  defmodule TunnellingAck do
    defstruct communication_channel_id: nil,
      sequence_counter: nil,
      status: nil
  end

  def encode_tunnelling_request(%{telegram: telegram})
      when not is_binary(telegram) do
    {:error, {:frame_encode_error, telegram, "invalid telegram format"}}
  end

  def encode_tunnelling_request(req) do
    with {:ok, id} <- encode_communication_channel_id(req.communication_channel_id),
         {:ok, sequence_counter} <- encode_sequence_counter(req.sequence_counter) do
      {:ok, <<0x04>> <> id <> sequence_counter <> <<0x00>> <> req.telegram}
    end
  end

  def encode_tunnelling_ack(ack) do
    with {:ok, id} <- encode_communication_channel_id(ack.communication_channel_id),
         {:ok, sequence_counter} <- encode_sequence_counter(ack.sequence_counter),
         {:ok, status} <- encode_tunnelling_ack_status(ack.status) do
      {:ok, <<0x04>> <> id <> sequence_counter <> status}
    end
  end

  defp encode_communication_channel_id(id)
      when not is_integer(id) or id < 0 or id > 255 do
    {:error, {:frame_encode_error, id, "invalid communication channel id"}}
  end

  defp encode_communication_channel_id(id),
    do: {:ok, <<id>>}

  defp encode_sequence_counter(counter)
      when not is_integer(counter) or counter < 0 or counter > 255 do
    {:error, {:frame_encode_error, counter, "invalid sequence counter"}}
  end

  defp encode_sequence_counter(counter),
    do: {:ok, <<counter>>}

  defp encode_tunnelling_ack_status(status) do
    case Core.constant(status) do
      nil -> {:error, {:frame_encode_error, status, "unsupported tunnelling ack status"}}
      status -> {:ok, <<status>>}
    end
  end

  def encode_connection_request_data(%{knx_layer: knx_layer}) do
    with {:ok, knx_layer} <- encode_knx_layer(knx_layer) do
      {:ok, <<knx_layer, 0x00>>}
    end
  end

  def encode_connection_request_data(connection_data),
    do: {:error, {:frame_encode_error, connection_data, "invalid format of connection request data"}}

  defp encode_knx_layer(knx_layer) do
    case constant(knx_layer) do
      nil -> {:error, {:frame_encode_error, knx_layer, "unsupported KNX layer"}}
      knx_layer -> {:ok, knx_layer}
    end
  end

  def encode_connection_response_data(%{knx_individual_address: address})
      when is_binary(address) do
    case split_individual_address(address) do
      [area, line, bus_device] -> {:ok, <<area::4, line::4, bus_device>>}
      _ -> {:error, {:frame_encode_error, address, "invalid format of individual address"}}
    end
  end

  def encode_connection_response_data(connection_data),
    do: {:error, {:frame_encode_error, connection_data, "invalid format of connection response data"}}

  defp split_individual_address(address) do
    address
    |> String.trim_trailing(".")
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
  end

  def decode_tunnelling_request(
      <<
        _length, communication_channel_id,
        sequence_counter, _,
        telegram::binary
      >>) do

    tunnelling_request = %TunnellingRequest{
      communication_channel_id: communication_channel_id,
      sequence_counter: sequence_counter,
      telegram: telegram
    }
    {:ok, tunnelling_request}
  end

  def decode_tunnelling_request(frame),
    do: {:error, {:frame_decode_error, frame, "invalid format of tunnelling request frame"}}

  def decode_tunnelling_ack(
      <<
        _length, communication_channel_id,
        sequence_counter, status
      >>) do
    tunnelling_ack = %TunnellingAck{
      communication_channel_id: communication_channel_id,
      sequence_counter: sequence_counter,
      status: Core.constant(status)
    }
    {:ok, tunnelling_ack}
  end

  def decode_tunnelling_ack(frame),
    do: {:error, {:frame_decode_error, frame, "invalid format of tunnelling ack frame"}}

  def decode_connection_request_data(<<knx_layer::8, _::8>>) do
    case constant(knx_layer) do
      nil -> {:error, {:frame_decode_error, knx_layer, "unsupported KNX layer"}}
      layer ->
        {:ok, %{knx_layer: layer}}
    end
  end

  def decode_connection_response_data(<<area::4, line::4, bus_device>>) do
    {:ok, %{knx_individual_address: "#{area}.#{line}.#{bus_device}"}}
  end

  def decode_connection_response_data(crd),
    do: {:error, {:frame_decode_error, crd, "invalid format of connection response data block"}}
end
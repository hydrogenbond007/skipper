import json
from base64 import b64decode
from dataclasses import dataclass

from cosmpy.protos.cosmos.tx.v1beta1.tx_pb2 import Tx
from cosmpy.protos.cosmwasm.wasm.v1.tx_pb2 import MsgExecuteContract
from evmospy.evmosproto.ethermint.evm.v1.tx_pb2 import MsgEthereumTx, LegacyTx

from src.decoder.decoder import Decoder
from src.contract import Contract 


@dataclass
class EVMDecoder(Decoder):
    """ CosmWasm VM implementation of the Decoder class.
        Currently works for Juno and Terra 2.
    """
    relevant_type_url: str = "/ethermint.evm.v1.MsgEthereumTx"

    @staticmethod
    def decode_tx(tx: str) -> tuple[bytes, Tx]:
        """ This method is used to decode a transaction,
            and return the transaction bytes and the decoded tx.
        """
        tx_bytes: bytes = b64decode(tx)
        return tx_bytes, Tx().FromString(tx_bytes)

    @staticmethod
    def decode_message(message) -> tuple[MsgExecuteContract, LegacyTx]:
        """ This method is used to decode a message,
            and return the message value and the decoded msg.
        """
        message_value: MsgEthereumTx = MsgEthereumTx().FromString(message.value)
        native_eth_tx: LegacyTx = LegacyTx().FromString(message_value.data.value)
        return message_value, native_eth_tx

    @staticmethod
    def get_relevant_contract(contracts: dict, 
                              message_value, 
                              msg: LegacyTx) -> Contract or None:
        """ This method is used to get the relevant contract
            from a message, if it exists.
        """
        return contracts.get(msg.to)
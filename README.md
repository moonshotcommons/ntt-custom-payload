<div align="center">
  <img src="images/ntt-logo.png">
</div>

---

# Overview

Wormhole’s Native Token Transfers (NTT) is an open, flexible, and composable framework for transferring tokens across blockchains without liquidity pools. Integrators have full control over how their Natively Transferred Tokens (NTTs) behave on each chain, including the token standard and metadata. For existing token deployments, the framework can be used in “locking” mode which preserves the original token supply on a single chain. Otherwise, the framework can be used in “burning” mode to deploy natively multichain tokens with the supply distributed among multiple chains.

## Design

There are two basic components to NTT:

(1) **Transceiver**: This contract is responsible for sending NTT transfers forwarded through the `NttManager` on the source chain and delivered to a corresponding peer `NttManager` on the recipient chain. Transceivers should follow the `ITransceiver` interface. Transceivers can be defined independently of Wormhole core and can be modified to support any verification backend. See [docs/Transceiver.md](./docs/Transceiver.md) for more info.

(2) **NttManager**: The NttManager contract is responsible for managing the token and the Transceivers. It also handles the rate-limiting and the message attestation logic. Note that each `NttManager` corresponds to a single token. However, a single `NttManager` can control multiple transceivers. See [docs/NttManager.md](./docs/NttManager.md) for more info.

<figure>
  <img src="images/ntt_architecture__with_custom_attestation.jpg" alt="NTT Architecture Diagram">
  <figcaption>Figure: NTT Architecture Diagram with Custom Attestations.</figcaption>
</figure>

## Amount trimming

In the payload, amounts are encoded as unsigned 64 bit integers, and capped at the configured `TRIMMED_DECIMALS` (e.g. 8) decimal value.
This means that if on the sending chain, the token has more than than `TRIMMED_DECIMALS`, then the amount is trimmed.
The amount that's removed during trimming is referred to as "dust". The contracts ensure to never destroy dust.
The NTT manager contracts additionally keep track of the token decimals of the other connected chains. When sending to a chain whose token decimals are less than `TRIMMED_DECIMALS`, the amount is instead trimmed to those decimals to ensure that the recipient contract can handle the amount without destroying dust.

The payload includes the trimmed amount, together with the decimals that trimmed amount is expressed in. This number is the minimum of (`TRIMMED_DECIMALS`, source token decimals, destination token decimals).

## Rate-Limiting

NTT supports rate-limiting both on the sending and destination chains. If a transfer is rate-limited on the source chain and queueing is enabled via `shouldQueue = true`, transfers are placed into an outbound queue and can be released after the expiry of the rate limit duration. Transfers that are rate-limited on the destination chain are added to an inbound queue with a similar release delay.

## Cancel-Flows

If users bridge frequently between a given source chain and destination chain, the capacity could be exhausted quickly. This can leave other users rate-limited, potentially delaying their transfers. To mitigate this issue, the outbound transfer cancels the inbound rate-limit on the source chain (refills the inbound rate-limit by an amount equal to that of the outbound transfer amount) and vice-versa, the inbound transfer cancels the outbound rate-limit on the destination chain (refills the outbound rate-limit by an amount equal to the inbound transfer amount).

## Wormhole Governance

There are general purpose governance contracts implemented for both EVM and Solana, which allow Wormhole Guardians to govern arbitrary contracts if they choose to do so (and the governed contract chooses to as well).
The concrete interpretation of the governance packets are runtime specific, but they both follow the same spec (as defined in https://github.com/wormhole-foundation/wormhole/blob/main/whitepapers/0002_governance_messaging.md).
Namely, the governance messages start with a 32 byte module identifier, which is the string `"GeneralPurposeGovernance"` left padded, followed by a 1 byte action identifier, finally followed by a chain id.

The action identifier specifies the runtime. Currently, these are as follows:

- 0: undefined
- 1: evm
- 2: solana

---

⚠️ **WARNING:** Ensure that if the `NttManager` on the source chain is configured to be in `LOCKING` mode, the corresponding `NttManager`s on the target chains are configured to be in `BURNING` mode. If not, transfers will NOT go through and user funds may be lost! Proceed with caution!

:warning: This software is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License. Or plainly spoken - this is a very complex piece of software which targets a bleeding-edge, experimental smart contract runtime. Mistakes happen, and no matter how hard you try and whether you pay someone to audit it, it may eat your tokens, set your printer on fire or startle your cat. Cryptocurrencies are a high-risk investment, no matter how fancy.

Wormhole contributors encourage integrators to evaluate their own regulatory obligations when integrating this code into their products, including, but not limited to, those related to economic or trade sanctions compliance.

Source Chain Tx:
  https://sepolia-optimism.etherscan.io/tx/0x1dfbed30fd89fe215ce88ce722a421949fc6cfbc768ac66fc8f22d986b69d46a#eventlog

  wormhole scan -> payload -> parsedPayload -> nttMessage -> additionalPayload: https://wormholescan.io/#/tx/0x1dfbed30fd89fe215ce88ce722a421949fc6cfbc768ac66fc8f22d986b69d46a?network=Testnet&view=advanced

Target Chain Tx:
  https://sepolia.arbiscan.io/tx/0x98ded06ab95ad09a4ff2087ae7ef1d40d993392fff8a1adccd05971854a9e038#eventlog

-------------------------
Source Chain Tx:https://sepolia-optimism.etherscan.io/tx/0x04c18d63314afb8019b830552c2730a475071ff896c54b641b639cc757127ebe

Target Chain Tx:https://sepolia.arbiscan.io/tx/0xcd6006d661a1bf15b38ccc6a3b59d6f617390da25cacaa18fc8da28dea6e85e5
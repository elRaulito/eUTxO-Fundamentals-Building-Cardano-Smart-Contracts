use aiken/collection/dict
use aiken/collection/list
use aiken/primitive/bytearray.{to_string}
use aiken/primitive/string.{from_bytearray}
use cardano/address.{Address, Script}
use cardano/assets.{
  AssetName, PolicyId, from_asset, from_asset_list, quantity_of,
}
use cardano/transaction.{
  Input, NoDatum, Output, OutputReference, Transaction, placeholder,
}
use mocktail/virgin_key_hash.{mock_policy_id}
use mocktail/virgin_output_reference.{mock_utxo_ref}

pub type Action {
  Mint
  Burn
}

validator fract_nft(
  nft_policy_id: PolicyId,
  nft_asset_name: AssetName,
  mint_tokens_quantity: Int,
  burn_tokens_quantity: Int,
  uxto_onetime: OutputReference,
) {
  mint(redeemer: Action, policy_id: PolicyId, self: Transaction) {
    let Transaction { inputs, outputs, mint, .. } = self

    let assets = mint |> assets.tokens(policy_id) |> dict.to_pairs()

    expect [Pair(fract_asset_name, _)] = assets
    let valid_fract_asset_name =
      string.concat(left: @"fract-", right: from_bytearray(nft_asset_name))

    expect valid_fract_asset_name == to_string(fract_asset_name)

    when redeemer is {
      Mint -> {
        expect Some(_input) =
          list.find(
            inputs,
            fn(input) { input.output_reference == uxto_onetime },
          )
        validate_mint(
          assets,
          inputs,
          outputs,
          policy_id,
          nft_policy_id,
          nft_asset_name,
          mint_tokens_quantity,
        )
      }
      Burn ->
        validate_burn(
          assets,
          policy_id,
          inputs,
          nft_policy_id,
          nft_asset_name,
          burn_tokens_quantity,
        )
    }
  }

  spend(_d: Option<Data>, _r: Data, utxo: OutputReference, self: Transaction) {
    let Transaction { inputs, mint, .. } = self

    expect Some(own_input) =
      list.find(inputs, fn(input) { input.output_reference == utxo })

    expect Script(policy_id) = own_input.output.address.payment_credential

    expect [Pair(_, quantity)] =
      mint |> assets.tokens(policy_id) |> dict.to_pairs

    (quantity <= -burn_tokens_quantity)?
  }

  else(_) {
    fail
  }
}

fn validate_mint(
  assets: Pairs<ByteArray, Int>,
  inputs: List<Input>,
  outputs: List<Output>,
  policy_id: PolicyId,
  nft_policy_id: PolicyId,
  nft_asset_name: AssetName,
  mint_tokens_quantity: Int,
) {
  let is_nft_in_inputs =
    inputs
      |> list.any(
          fn(input) {
            quantity_of(input.output.value, nft_policy_id, nft_asset_name) == 1
          },
        )

  let is_nft_in_outputs =
    outputs
      |> list.any(
          fn(output) {
            and {
              output.address.payment_credential == Script(policy_id),
              quantity_of(output.value, nft_policy_id, nft_asset_name) == 1,
            }
          },
        )

  let is_mint_quantity_valid = and {
      list.length(assets) == 1,
      assets
        |> list.all(fn(Pair(_, quantity)) { quantity == mint_tokens_quantity }),
    }

  and {
    is_nft_in_inputs?,
    is_nft_in_outputs?,
    is_mint_quantity_valid?,
  }
}

fn validate_burn(
  assets: Pairs<ByteArray, Int>,
  policy_id: PolicyId,
  inputs: List<Input>,
  nft_policy_id: PolicyId,
  nft_asset_name: AssetName,
  burn_tokens_quantity: Int,
) {
  let is_burn_tokens_valid =
    assets
      |> list.any(fn(Pair(_, quantity)) { quantity <= -burn_tokens_quantity })

  let is_input_valid =
    inputs
      |> list.any(
          fn(input) {
            and {
              quantity_of(input.output.value, nft_policy_id, nft_asset_name) == 1,
              input.output.address.payment_credential == Script(policy_id),
            }
          },
        )

  is_burn_tokens_valid? && is_input_valid?
}

// Tests

test test_mint() {
  let the_nft_policy_id = mock_policy_id(0)
  let the_nft_asset_name = "my_nft"
  let the_nft = from_asset(the_nft_policy_id, the_nft_asset_name, 1)

  let tx_input =
    Input {
      output_reference: mock_utxo_ref(0, 0),
      output: Output {
        address: Address {
          // input from some place
          payment_credential: Script(mock_policy_id(5)),
          stake_credential: None,
        },
        value: the_nft,
        datum: NoDatum,
        reference_script: None,
      },
    }

  let tx_output =
    Output {
      address: Address {
        // Output going into the validator
        payment_credential: Script(mock_policy_id(1)),
        stake_credential: None,
      },
      value: the_nft,
      datum: NoDatum,
      reference_script: None,
    }

  let mint =
    from_asset_list([Pair(mock_policy_id(1), [Pair("fract-my_nft", 100)])])

  let tx =
    Transaction {
      ..placeholder,
      mint: mint,
      inputs: [tx_input],
      outputs: [tx_output],
    }

  fract_nft.mint(
    the_nft_policy_id,
    the_nft_asset_name,
    100,
    50,
    mock_utxo_ref(0, 0),
    Mint,
    mock_policy_id(1),
    tx,
  )
}

test test_burn() {
  let the_nft_policy_id = mock_policy_id(0)
  let the_nft_asset_name = "my_nft"
  let the_nft = from_asset(the_nft_policy_id, the_nft_asset_name, 1)
  let validator_hash = mock_policy_id(1)

  let tx_input =
    Input {
      // output reference changed
      output_reference: mock_utxo_ref(0, 1),
      output: Output {
        address: Address {
          // input from validator
          payment_credential: Script(validator_hash),
          stake_credential: None,
        },
        value: the_nft,
        datum: NoDatum,
        reference_script: None,
      },
    }

  let mint =
    from_asset_list([Pair(mock_policy_id(1), [Pair("fract-my_nft", -50)])])

  let tx = Transaction { ..placeholder, mint: mint, inputs: [tx_input] }

  fract_nft.mint(
    the_nft_policy_id,
    the_nft_asset_name,
    100,
    50,
    mock_utxo_ref(0, 0),
    Burn,
    validator_hash,
    tx,
  )
}

test test_spend() {
  let the_nft_policy_id = mock_policy_id(0)
  let the_nft_asset_name = "my_nft"
  let the_nft = from_asset(the_nft_policy_id, the_nft_asset_name, 1)
  let validator_hash = mock_policy_id(1)

  let own_oref = mock_utxo_ref(0, 1)

  let tx_input =
    Input {
      // output reference changed
      output_reference: own_oref,
      output: Output {
        address: Address {
          // input from validator
          payment_credential: Script(validator_hash),
          stake_credential: None,
        },
        value: the_nft,
        datum: NoDatum,
        reference_script: None,
      },
    }

  let mint = from_asset_list([Pair(mock_policy_id(1), [Pair("fract1", -50)])])

  let tx = Transaction { ..placeholder, mint: mint, inputs: [tx_input] }

  fract_nft.spend(
    the_nft_policy_id,
    the_nft_asset_name,
    100,
    50,
    mock_utxo_ref(0, 0),
    None,
    "",
    own_oref,
    tx,
  )
}

test test_mint_with_spend() {
  let the_nft_policy_id = mock_policy_id(0)
  let the_nft_asset_name = "my_nft"
  let the_nft = from_asset(the_nft_policy_id, the_nft_asset_name, 1)
  let validator_hash = mock_policy_id(1)

  let own_oref = mock_utxo_ref(0, 1)

  let tx_input =
    Input {
      // output reference changed
      output_reference: own_oref,
      output: Output {
        address: Address {
          // input from validator
          payment_credential: Script(validator_hash),
          stake_credential: None,
        },
        value: the_nft,
        datum: NoDatum,
        reference_script: None,
      },
    }

  let mint =
    from_asset_list([Pair(mock_policy_id(1), [Pair("fract-my_nft", -50)])])

  let tx = Transaction { ..placeholder, mint: mint, inputs: [tx_input] }

  and {
    fract_nft.mint(
      the_nft_policy_id,
      the_nft_asset_name,
      100,
      50,
      mock_utxo_ref(0, 0),
      Burn,
      validator_hash,
      tx,
    ),
    fract_nft.spend(
      the_nft_policy_id,
      the_nft_asset_name,
      100,
      50,
      mock_utxo_ref(0, 0),
      None,
      "",
      own_oref,
      tx,
    ),
  }
}

use aiken/collection/list
use aiken/crypto.{ScriptHash, VerificationKeyHash}
use aiken/interval.{Finite}
use cardano/address.{Script}
use cardano/transaction.{Input, Transaction, ValidityRange, placeholder}
use mocktail/virgin_key_hash.{mock_pub_key_hash}

pub type User {
  SingleSigner(VerificationKeyHash)
  MultiSigner(ScriptHash)
}

pub type SWDatum {
  lock_duration: Int,
}

validator smart_wallet(user: User) {
  spend(datum: Option<SWDatum>, _r: Data, _o: Data, self: Transaction) {
    let Transaction { inputs, .. } = self

    and {
      is_signed(self, user, inputs),
      when datum is {
        Some(SWDatum { lock_duration }) ->
          is_time_reached(self.validity_range, lock_duration)
        _ -> True
      },
    }
  }

  else(_) {
    fail
  }
}

fn is_signed(tx: Transaction, user: User, inputs: List<Input>) {
  when user is {
    SingleSigner(signer_vk) -> list.has(tx.extra_signatories, signer_vk)

    MultiSigner(script_hash) -> {
      let script_cred = Script(script_hash)
      list.any(
        inputs,
        fn(input) {
          let address = input.output.address
          address.payment_credential == script_cred
        },
      )
    }
  }
}

fn is_time_reached(range: ValidityRange, lock_time: Int) {
  when range.lower_bound.bound_type is {
    Finite(time_now) -> lock_time <= time_now
    _ -> False
  }
}

// Tests

fn get_tx(sign: List<VerificationKeyHash>) {
  Transaction { ..placeholder, extra_signatories: sign }
}

test test_single_signer() {
  let tx = get_tx([mock_pub_key_hash(0)])

  smart_wallet.spend(SingleSigner(mock_pub_key_hash(0)), None, "", "", tx)
}

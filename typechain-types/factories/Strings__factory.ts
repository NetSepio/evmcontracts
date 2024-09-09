/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type { Strings, StringsInterface } from "../Strings";

const _abi = [
  {
    inputs: [
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "length",
        type: "uint256",
      },
    ],
    name: "StringsInsufficientHexLength",
    type: "error",
  },
];

const _bytecode =
  "0x60566037600b82828239805160001a607314602a57634e487b7160e01b600052600060045260246000fd5b30600052607381538281f3fe73000000000000000000000000000000000000000030146080604052600080fdfea264697066735822122039ee855a7d6a3f72d6da11b4a850b082834946baf95bab3e71bbdb0073baa95f64736f6c63430008140033";

type StringsConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: StringsConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class Strings__factory extends ContractFactory {
  constructor(...args: StringsConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "Strings";
  }

  deploy(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<Strings> {
    return super.deploy(overrides || {}) as Promise<Strings>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): Strings {
    return super.attach(address) as Strings;
  }
  connect(signer: Signer): Strings__factory {
    return super.connect(signer) as Strings__factory;
  }
  static readonly contractName: "Strings";
  public readonly contractName: "Strings";
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): StringsInterface {
    return new utils.Interface(_abi) as StringsInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): Strings {
    return new Contract(address, _abi, signerOrProvider) as Strings;
  }
}

import { loadPolicy as opaPolicyLoader } from '@open-policy-agent/opa-wasm';

interface OpaLoadedPolicy<T = any, R = any> {
  evaluate(input: T, entrypoint?: string | number | undefined): [{ result: R }]
}

type OpaPolicyWasm = BufferSource | WebAssembly.Module;

type OpaPolicyLoader = (regoWasm: OpaPolicyWasm, memoryDescriptor?: number | WebAssembly.MemoryDescriptor | undefined, customBuiltins?: { [builtinName: string]: Function; } | undefined) => Promise<OpaLoadedPolicy>;

export interface IOpaPolicy<T = any, R = any> {
  evaluate(input: T): Promise<R>;
}

export class OpaPolicy<T = any, R = any> implements IOpaPolicy<T, R> {
  protected readonly _loader: OpaPolicyLoader;

  protected readonly _policyWasm: OpaPolicyWasm;

  protected _policy: OpaLoadedPolicy | null = null;

  constructor(policyWasm: OpaPolicyWasm, loader?: OpaPolicyLoader) {
    this._loader = loader || opaPolicyLoader;
    this._policyWasm = policyWasm;
  }

  public readonly evaluate = async (input: T): Promise<R> => {
    if (!this._policy)
      this._policy = await this._loader(this._policyWasm);
    const response = this._policy.evaluate(input);
    return response[0].result;
  };
}

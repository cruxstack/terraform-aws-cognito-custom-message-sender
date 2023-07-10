import * as base64 from 'base64-js';
import * as crypto from '@aws-crypto/client-node';

export interface IDecrypter {
  decrypt: (encryptedText: string) => Promise<string>
}

export class Decrypter implements IDecrypter {
  private _client;

  private _keyring: crypto.KeyringNode;

  constructor(keyId: string) {
    this._client = crypto.buildClient(crypto.CommitmentPolicy.FORBID_ENCRYPT_ALLOW_DECRYPT);
    this._keyring = new crypto.KmsKeyringNode({ keyIds: [keyId] });
  }

  public readonly decrypt = async (encryptedText: string): Promise<string> => {
    const { plaintext } = await this._client.decrypt(this._keyring, base64.toByteArray(encryptedText));
    return plaintext.toString();
  };
}

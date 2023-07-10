import * as base64 from 'base64-js';
import * as crypto from '@aws-crypto/client-node';
import { Decrypter } from './decrypter'; // replace 'your-file' with the actual file name

jest.mock('base64-js');
jest.mock('@aws-crypto/client-node');

describe('Decrypter Service', () => {
  const mockKeyId = 'mockKeyId';
  const mockEncryptedText = 'mockEncryptedText';
  const mockPlaintext = 'mockPlaintext';

  let decrypter: Decrypter;

  beforeEach(() => {
    (crypto.buildClient as jest.MockedFunction<typeof crypto.buildClient>).mockReturnValue({
      decrypt: jest.fn().mockResolvedValue({ plaintext: Buffer.from(mockPlaintext) }),
    } as any);

    (crypto.KmsKeyringNode as jest.MockedClass<typeof crypto.KmsKeyringNode>).mockImplementation(() => ({} as crypto.KmsKeyringNode));

    (base64.toByteArray as jest.MockedFunction<typeof base64.toByteArray>).mockReturnValue(Buffer.from(mockEncryptedText));

    decrypter = new Decrypter(mockKeyId);
  });

  it('should decrypt text', async () => {
    const decryptedText = await decrypter.decrypt(mockEncryptedText);

    expect(decryptedText).toBe(mockPlaintext);
    expect(crypto.buildClient).toHaveBeenCalledWith(crypto.CommitmentPolicy.FORBID_ENCRYPT_ALLOW_DECRYPT);
    expect(crypto.KmsKeyringNode).toHaveBeenCalledWith({ keyIds: [mockKeyId] });
    expect(base64.toByteArray).toHaveBeenCalledWith(mockEncryptedText);
  });

  afterEach(() => {
    jest.resetAllMocks();
  });
});

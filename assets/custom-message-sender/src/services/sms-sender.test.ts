import { IDecrypter } from '../commons/decrypter';
import { AppError, AppErrorName, AppInputError } from '../commons/errors';
import { CognitoUserAttributes, IMessageClient, SmsMessagePayload } from '../commons/types';
import { IHistoryRepository } from '../repositories/history';
import { SmsSender, SmsSenderConfig, SmsSenderPolicy, SmsSenderTrigger } from './sms-sender';

describe('SmsSender Service', () => {
  const mockSmsSenderEncryptedCode = 'FAKE_ENCRYPTED_CODE';

  const mockUserAttributePhoneNumber = '+18135555555';

  let mockDecrypter: jest.Mocked<IDecrypter>;

  let mockSms: jest.Mocked<IMessageClient<SmsMessagePayload>>;

  let mockHistoryRepo: jest.Mocked<IHistoryRepository>;

  let mockSmsSenderConfig: SmsSenderConfig;

  let mockSmsSenderPolicy: SmsSenderPolicy;

  let mockUserAttributes: CognitoUserAttributes;

  beforeEach(() => {
    mockDecrypter = {
      decrypt: jest.fn().mockResolvedValue('1234'),
    };

    mockSms = {
      send: jest.fn().mockResolvedValue(undefined),
    };

    mockHistoryRepo = {
      save: jest.fn().mockResolvedValue(undefined),
      getCountByPhoneNumber: jest.fn().mockResolvedValue(0),
      getCountByUserId: jest.fn().mockResolvedValue(0),
    };

    mockSmsSenderConfig = {
      smsSenderEnabled: true,
      smsThrottlePeriod: 15,
    };

    mockSmsSenderPolicy = {
      evaluate: jest.fn().mockResolvedValue({
        action: 'allow',
        allow: {
          message: 'FAKE_MESSAGE',

        },
      }),
    };

    mockUserAttributes = {
      email: 'foobar@email.com',
      email_verified: 'true',
      phone_number: mockUserAttributePhoneNumber,
      phone_number_verified: 'true',
      sub: '00000000-0000-0000-0000-000000000000',
    };
  });

  it('should throw an error when service but disabled', async () => {
    mockSmsSenderConfig.smsSenderEnabled = false;
    const sender = new SmsSender(mockDecrypter, mockSms, mockHistoryRepo, mockSmsSenderPolicy, mockSmsSenderConfig);
    let error: unknown;

    try {
      await sender.send(SmsSenderTrigger.SIGN_UP, mockUserAttributes, mockSmsSenderEncryptedCode);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeInstanceOf(AppInputError);
    expect((error as AppInputError).errorName).toEqual(AppErrorName.SERVICE_NOT_ENABLED);
  });

  it('should save request in history', async () => {
    const sender = new SmsSender(mockDecrypter, mockSms, mockHistoryRepo, mockSmsSenderPolicy, mockSmsSenderConfig);
    let error: unknown;

    try {
      await sender.send(SmsSenderTrigger.SIGN_UP, mockUserAttributes, mockSmsSenderEncryptedCode);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBe(undefined);
    expect(mockHistoryRepo.save).toHaveBeenCalled();
    expect(mockHistoryRepo.save).toHaveBeenCalledWith({
      type: 'sms',
      trigger: SmsSenderTrigger.SIGN_UP,
      userId: mockUserAttributes.sub,
      userEmailAddress: mockUserAttributes.email,
      userPhoneNumber: mockUserAttributes.phone_number,
      userPhoneNumberCountry: 'US',
    });
  });

  it('should throw an error for invalid phone numbers', async () => {
    mockUserAttributes.phone_number = 'invalid-phone-number';
    const sender = new SmsSender(mockDecrypter, mockSms, mockHistoryRepo, mockSmsSenderPolicy, mockSmsSenderConfig);
    let error: unknown;

    try {
      await sender.send(SmsSenderTrigger.SIGN_UP, mockUserAttributes, mockSmsSenderEncryptedCode);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeInstanceOf(AppInputError);
    expect((error as AppInputError).errorName).toEqual(AppErrorName.USER_PHONE_NUMBER_IS_INVALID);
  });

  it('should throw an error when message is blocked', async () => {
    mockSmsSenderPolicy.evaluate = jest.fn().mockResolvedValue({
      action: 'block',
      block: {
        reason: 'FAKE_BLOCK_REASON',
      },
    });

    const sender = new SmsSender(mockDecrypter, mockSms, mockHistoryRepo, mockSmsSenderPolicy, mockSmsSenderConfig);
    let error: unknown;

    try {
      await sender.send(SmsSenderTrigger.SIGN_UP, mockUserAttributes, mockSmsSenderEncryptedCode);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeInstanceOf(AppInputError);
    expect((error as AppInputError).errorName).toEqual(AppErrorName.MESSAGE_BLOCKED);
  });

  it('should throw an error when decryption fails', async () => {
    mockDecrypter.decrypt = jest.fn().mockRejectedValue(new AppError('decryption failed', AppErrorName.DECRYPTION_FAILED));

    const sender = new SmsSender(mockDecrypter, mockSms, mockHistoryRepo, mockSmsSenderPolicy, mockSmsSenderConfig);
    let error: unknown;

    try {
      await sender.send(SmsSenderTrigger.SIGN_UP, mockUserAttributes, mockSmsSenderEncryptedCode);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeInstanceOf(AppError);
    expect((error as AppError).errorName).toEqual(AppErrorName.DECRYPTION_FAILED);
  });

  it('should throw an error when sms sending fails', async () => {
    mockSms.send = jest.fn().mockRejectedValue(new AppError('SMS sending failed', AppErrorName.SMS_SENDING_FAILED));

    const sender = new SmsSender(mockDecrypter, mockSms, mockHistoryRepo, mockSmsSenderPolicy, mockSmsSenderConfig);
    let error: unknown;

    try {
      await sender.send(SmsSenderTrigger.SIGN_UP, mockUserAttributes, mockSmsSenderEncryptedCode);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeInstanceOf(AppError);
    expect((error as AppError).errorName).toEqual(AppErrorName.SMS_SENDING_FAILED);
  });

  afterEach(() => {
    jest.resetAllMocks();
  });
});

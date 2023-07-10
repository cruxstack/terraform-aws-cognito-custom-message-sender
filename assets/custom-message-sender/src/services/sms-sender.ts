import { parsePhoneNumberFromString } from 'libphonenumber-js';
import { IDecrypter } from '../commons/decrypter';
import { AppErrorName, AppInputError } from '../commons/errors';
import { CognitoUserAttributes, IMessageSender, IMessageClient, SmsMessagePayload } from '../commons/types';
import { IHistoryRepository } from '../repositories/history';
import { IOpaPolicy } from '../opa/opa-policy';

const MIN_IN_MILLIS = 60 * 1000;

export enum SmsSenderTrigger {
  ACCOUNT_TAKE_OVER_NOTIFICATION = 'CustomSMSSender_AccountTakeOverNotification',
  ADMIN_CREATE_USER = 'CustomSMSSender_AdminCreateUser',
  AUTHENTICATION = 'CustomSMSSender_Authentication',
  FORGOT_PASSWORD = 'CustomSMSSender_ForgotPassword',
  RESEND_CODE = 'CustomSMSSender_ResendCode',
  SIGN_UP = 'CustomSMSSender_SignUp',
  UPDATE_USER_ATTRIBUTE = 'CustomSMSSender_UpdateUserAttribute',
  VERIFY_USER_ATTRIBUTE = 'CustomSMSSender_VerifyUserAttribute',
}

export type SmsSenderTriggerType = `${SmsSenderTrigger}`;

export interface SmsSenderPhoneNumber {
  carrierCode: string | null
  countryCallingCode: string
  country: string
  nationalNumber: string
  number: string
  isValid: boolean
  isPossible: boolean
}

export interface SmsSenderPolicyEvaluateInput {
  trigger: SmsSenderTriggerType
  userAttributes: CognitoUserAttributes
  phoneNumberData: SmsSenderPhoneNumber
  history: {
    recentAttempts: number
  }
}

export interface SmsSenderPublishAllowedData {
  message: string
  messageType: 'Transactional'
  senderId: string
  shortCode: string
}

export interface SmsSenderPublishBlockedData {
  reason: string
}

export interface SmsSenderPolicyEvaluateOutput {
  action: 'allow' | 'block'
  block: SmsSenderPublishBlockedData
  allow: SmsSenderPublishAllowedData
}

export interface SmsSenderPolicy extends IOpaPolicy<SmsSenderPolicyEvaluateInput, SmsSenderPolicyEvaluateOutput> { }

export interface SmsSenderConfig {
  smsSenderEnabled: boolean
  smsThrottlePeriod: number
}

export class SmsSender implements IMessageSender<SmsSenderTriggerType> {
  private readonly _enabled: boolean;

  private readonly _decrypter: IDecrypter;

  private readonly _historyRepo: IHistoryRepository;

  private readonly _policy: SmsSenderPolicy;

  private readonly _sms: IMessageClient<SmsMessagePayload>;

  private readonly _throttlePeriodInMinutes: number;


  constructor(decrypter: IDecrypter, sms: IMessageClient<SmsMessagePayload>, historyRepo: IHistoryRepository, policy: SmsSenderPolicy, config: SmsSenderConfig) {
    this._enabled = config.smsSenderEnabled;
    this._decrypter = decrypter;
    this._historyRepo = historyRepo;
    this._policy = policy;
    this._sms = sms;
    this._throttlePeriodInMinutes = config.smsThrottlePeriod;
  }

  public send = async (trigger: SmsSenderTriggerType, userAttributes: CognitoUserAttributes, ecryptedCode: string | null | undefined): Promise<void> => {
    if (!this._enabled)
      throw new AppInputError('sms sender is not enabled', AppErrorName.SERVICE_NOT_ENABLED);

    const phoneNumber = this._getUserPhoneNumber(userAttributes);
    await this._recordHistory(trigger, userAttributes, phoneNumber);

    const data = await this._process(phoneNumber, userAttributes, trigger);
    data.message = await this._transformMessage(data.message, ecryptedCode);
    await this._sendMessage(phoneNumber, data);
  };

  private _transformMessage = async (message: string, encryptedCode: string | null | undefined): Promise<string> => {
    if (!encryptedCode)
      return message;
    let code = await this._decrypter.decrypt(encryptedCode);
    return message.replace('{####}', code);
  };

  private _getUserPhoneNumber = (userAttributes: CognitoUserAttributes): SmsSenderPhoneNumber => {
    const phoneNumber = parsePhoneNumberFromString(userAttributes.phone_number ?? '');
    if (!phoneNumber || !phoneNumber.country)
      throw new AppInputError('user phone number is not valid', AppErrorName.USER_PHONE_NUMBER_IS_INVALID);
    return {
      number: phoneNumber.number,
      countryCallingCode: phoneNumber.countryCallingCode,
      country: phoneNumber.country,
      nationalNumber: phoneNumber.nationalNumber,
      carrierCode: phoneNumber.carrierCode || null,
      isValid: phoneNumber.isValid(),
      isPossible: phoneNumber.isPossible(),
    };
  };

  private _getHistory = async (phoneNumber: SmsSenderPhoneNumber): Promise<number> => {
    const timeNow = new Date();
    const timeSince = timeNow.getTime() - (this._throttlePeriodInMinutes * MIN_IN_MILLIS);

    const smsCountByPhoneNumber = await this._historyRepo.getCountByPhoneNumber(phoneNumber.number, timeSince);
    return smsCountByPhoneNumber;
  };

  private _recordHistory = async (trigger: SmsSenderTriggerType, userAttributes: CognitoUserAttributes, phoneNumber: SmsSenderPhoneNumber): Promise<void> => {
    await this._historyRepo.save({
      type: 'sms',
      trigger: trigger,
      userId: userAttributes.sub || '',
      userPhoneNumber: phoneNumber.number,
      userPhoneNumberCountry: phoneNumber.country || '',
      userEmailAddress: userAttributes.email || '',
    });
  };

  private _sendMessage = async (destination: SmsSenderPhoneNumber, data: SmsSenderPublishAllowedData): Promise<void> => {
    const payload: SmsMessagePayload = {
      destination: destination.number,
      message: data.message,
      messageType: data.messageType || 'Transactional',
      senderId: data.senderId || undefined,
      shortCode: data.shortCode || undefined,
    };
    await this._sms.send(payload);
  };

  private _process = async (phoneNumber: SmsSenderPhoneNumber, userAttributes: CognitoUserAttributes, trigger: SmsSenderTriggerType): Promise<SmsSenderPublishAllowedData> => {
    const policyInput: SmsSenderPolicyEvaluateInput = {
      trigger: trigger,
      userAttributes: userAttributes,
      phoneNumberData: phoneNumber,
      history: {
        recentAttempts: await this._getHistory(phoneNumber),
      },
    };
    const policyOutput = await this._policy.evaluate(policyInput);
    if (policyOutput.action === 'block')
      throw new AppInputError(policyOutput.block.reason || 'reason not provided', AppErrorName.MESSAGE_BLOCKED);
    return policyOutput.allow;
  };
}

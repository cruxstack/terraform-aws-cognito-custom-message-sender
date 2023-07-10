export enum AppErrorName {
  APP_CONFIG_MISSING_REQUIRED_PROPERTY = 'APP_CONFIG_MISSING_REQUIRED_PROPERTY',
  DECRYPTION_FAILED = 'DECRYPTION_FAILED',
  NOT_IMPLEMENTED = 'NOT_IMPLEMENTED',
  SERVICE_NOT_ENABLED = 'SERVICE_NOT_ENABLED',
  MESSAGE_BLOCKED = 'MESSAGE_BLOCKED',
  SMS_SENDING_FAILED = 'SMS_SENDING_FAILED',
  USER_ATTRIBUTE_IS_ACL_FILTERED = 'USER_ATTRIBUTE_IS_ACL_FILTERED',
  USER_EMAIL_IS_INVALID = 'USER_EMAIL_IS_INVALID',
  USER_EMAIL_IS_ACL_FILTERED = 'USER_EMAIL_IS_ACL_FILTERED',
  USER_PHONE_NUMBER_IS_INVALID = 'USER_PHONE_NUMBER_IS_INVALID',
  USER_PHONE_NUMBER_IS_ACL_FILTERED = 'USER_PHONE_NUMBER_IS_ACL_FILTERED',
  USER_TROTTLED = 'USER_TROTTLED',
  UNKNOWN = 'UNKNOWN',
}

export class AppError extends Error {
  public readonly errorName: AppErrorName;

  public constructor(message: string, errorName: AppErrorName) {
    super(message);
    this.errorName = errorName;

    Object.setPrototypeOf(this, AppError.prototype);
  }
}

export class AppInputError extends AppError {
  public constructor(message: string, errorName: AppErrorName) {
    super(message, errorName);

    Object.setPrototypeOf(this, AppInputError.prototype);
  }
}

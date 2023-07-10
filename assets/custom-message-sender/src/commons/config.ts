import { IHistoryRepositoryTableConfig } from '../repositories/history';
import { AppError, AppErrorName } from './errors';
import { logger } from './logger';

export interface AppEnvironmentVariables extends NodeJS.ProcessEnv {
  AWS_LAMBDA_FUNCTION_MEMORY_SIZE?: string,
  AWS_LAMBDA_FUNCTION_NAME?: string,
  AWS_REGION?: string,
  AWS_EXECUTION_ENV?: string,
  AWS_LAMBDA_FUNCTION_VERSION?: string,
  KMS_KEY_ID?: string,
  SMS_SENDER_ENABLED?: string,
  SMS_SENDER_POLICY_PATH?: string,
  SMS_THROTTLE_PERIOD_IN_MINUTES?: string,
  EMAIL_SENDER_ENABLED?: string;
  DDB_TABLE_HISTORY_NAME?: string,
  DDB_TABLE_HISTORY_TTL?: string,
  LOG_LEVEL?: string,
}

export enum AppConfigState {
  READY,
  NOT_READY,
}

export interface CustomEmailSenderConfig {
  historyStore: IHistoryRepositoryTableConfig;
  keyId: string;
  throttlePeriodInMinutes: number;
  smsSenderEnabled: boolean;
  smsSenderPolicyPath: string;
}

export class AppConfig {

  constructor(private _state = AppConfigState.NOT_READY, private _configuration: CustomEmailSenderConfig = {} as CustomEmailSenderConfig) { }

  public get state(): AppConfigState {
    return this._state;
  }

  public get emailSenderEnabled() {
    return process.env.EMAIL_SENDER_ENABLED === 'true'; // default to false
  }

  public get keyId(): string {
    return this._configuration.keyId;
  }

  public get smsSenderEnabled() {
    return this._configuration.smsSenderEnabled;
  }

  public get smsThrottlePeriod(): number {
    return this._configuration.throttlePeriodInMinutes;
  }

  public get smsSenderPolicyPath() {
    return this._configuration.smsSenderPolicyPath;
  }

  public get historyTable(): IHistoryRepositoryTableConfig {
    return this._configuration.historyStore;
  }

  public readonly update = async (config: AppEnvironmentVariables) => {
    if (!config.KMS_KEY_ID)
      throw new AppError('required environment is missing or empty: KMS_KEY_ID', AppErrorName.APP_CONFIG_MISSING_REQUIRED_PROPERTY);
    if (!config.DDB_TABLE_HISTORY_NAME)
      throw new AppError('required environment is missing or empty: DDB_TABLE_HISTORY_NAME', AppErrorName.APP_CONFIG_MISSING_REQUIRED_PROPERTY);

    this._configuration.keyId = config.KMS_KEY_ID.trim();

    this._configuration.historyStore = {
      name: config.DDB_TABLE_HISTORY_NAME || '',
      ttlLength: Number(config.DDB_TABLE_HISTORY_TTL || 43200),
    };

    this._configuration.throttlePeriodInMinutes = Number(config.SMS_THROTTLE_PERIOD_IN_MINUTES || 15);

    this._configuration.smsSenderEnabled = config.SMS_SENDER_ENABLED != 'false'; // default to true
    this._configuration.smsSenderPolicyPath = config.SMS_SENDER_POLICY_PATH || './policy.wasm';

    logger.configure(this._configuration);
    this._state = AppConfigState.READY;
    logger.debug({ config: this._configuration }, 'app config updated');
  };
}

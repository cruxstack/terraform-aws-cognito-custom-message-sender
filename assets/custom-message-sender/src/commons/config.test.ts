import { AppConfig, AppConfigState, AppEnvironmentVariables } from './config';
import { AppError, AppErrorName } from './errors';

describe('AppConfig Class', () => {
  let mockProcessEnv: AppEnvironmentVariables;

  beforeEach(() => {
    mockProcessEnv = {
      AWS_LAMBDA_FUNCTION_MEMORY_SIZE: '1024MB',
      AWS_LAMBDA_FUNCTION_NAME: 'test',
      AWS_REGION: 'local',
      AWS_EXECUTION_ENV: 'nodejs18x',
      AWS_LAMBDA_FUNCTION_VERSION: '',
      DDB_TABLE_HISTORY_NAME: 'history_table_name',
      KMS_KEY_ID: 'foobar',
      SMS_SENDER_ENABLED: 'true',
      SMS_THROTTLE_PERIOD_IN_MINUTES: '15',
      LOG_LEVEL: 'debug',
    };
  });

  it('should default to non-ready state', async () => {
    const config = new AppConfig();

    expect(config.state).toBe(AppConfigState.NOT_READY);
  });

  it('should default to ready state after successful update', async () => {
    const config = new AppConfig();

    await config.update(mockProcessEnv);

    expect(config.state).toBe(AppConfigState.READY);
  });

  it('should error if KMS_KEY_ID env is unset', async () => {
    delete mockProcessEnv.KMS_KEY_ID;
    let error: unknown;

    try {
      const config = new AppConfig();
      await config.update(mockProcessEnv);
    } catch (err) {
      error = err;
    }

    expect(error).toBeInstanceOf(AppError);
    expect((error as AppError).errorName).toBe(AppErrorName.APP_CONFIG_MISSING_REQUIRED_PROPERTY);
  });

  it('should default to true if SMS_SENDER_ENABLED env is unset', async () => {
    delete mockProcessEnv.SMS_SENDER_ENABLED;
    const config = new AppConfig();

    await config.update(mockProcessEnv);

    expect(config.smsSenderEnabled).toBe(true);
  });

  it('should propertly set keyId property', async () => {
    const config = new AppConfig();
    await config.update(mockProcessEnv);

    expect(config.keyId).toStrictEqual(mockProcessEnv.KMS_KEY_ID);
  });

  it('should propertly set historyTable property', async () => {
    mockProcessEnv.DDB_TABLE_HISTORY_TTL = '15';
    const config = new AppConfig();
    await config.update(mockProcessEnv);

    expect(config.historyTable).toStrictEqual({
      name: mockProcessEnv.DDB_TABLE_HISTORY_NAME,
      ttlLength: Number(mockProcessEnv.DDB_TABLE_HISTORY_TTL),
    });
  });

  it('should error if DDB_TABLE_HISTORY_NAME env is unset', async () => {
    delete mockProcessEnv.DDB_TABLE_HISTORY_NAME;
    let error: unknown;

    try {
      const config = new AppConfig();
      await config.update(mockProcessEnv);
    } catch (err) {
      error = err;
    }

    expect(error).toBeInstanceOf(AppError);
    expect((error as AppError).errorName).toBe(AppErrorName.APP_CONFIG_MISSING_REQUIRED_PROPERTY);
  });

  it('should propertly set limits property if respective envs is missing', async () => {
    const config = new AppConfig();
    await config.update(mockProcessEnv);

    expect(config.smsThrottlePeriod).toBeGreaterThan(0);
  });

  it('should propertly set limits property', async () => {
    mockProcessEnv.SMS_THROTTLE_PERIOD_IN_MINUTES = '1000';
    const config = new AppConfig();
    await config.update(mockProcessEnv);

    expect(config.smsThrottlePeriod).toStrictEqual(1000);
  });

  afterEach(() => {
    jest.resetAllMocks();
  });
});

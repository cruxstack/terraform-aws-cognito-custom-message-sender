import { SNSClient } from '@aws-sdk/client-sns';
import { CustomEmailSenderTriggerEvent, CustomSMSSenderTriggerEvent } from 'aws-lambda';
import { AwsSms } from './clients/aws-sms';
import { AppConfig, AppConfigState } from './commons/config';
import { Decrypter } from './commons/decrypter';
import { AppInputError } from './commons/errors';
import { logger } from './commons/logger';
import { CustomMessageSenderHandler, CustomMessageSenderInitializer } from './commons/types';
import { SmsSender } from './services/sms-sender';
import { HistoryRepository } from './repositories/history';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { AwsDdb } from './clients/aws-ddb';
import { readFile } from './commons/utils';
import { OpaPolicy } from './opa/opa-policy';

const isSmsTriggerEvent = (event: CustomSMSSenderTriggerEvent | CustomEmailSenderTriggerEvent): event is CustomSMSSenderTriggerEvent => {
  return event.triggerSource.startsWith('CustomSMSSender');
};

const isEmailTriggerEvent = (event: CustomSMSSenderTriggerEvent | CustomEmailSenderTriggerEvent): event is CustomEmailSenderTriggerEvent => {
  return event.triggerSource.startsWith('CustomEmailSender');
};

const init: CustomMessageSenderInitializer = () => {
  const config = new AppConfig();
  logger.info({ config }, 'config loaded');

  const awsSms = new AwsSms(new SNSClient({}));
  const awsDdb = new AwsDdb(new DynamoDBClient({}));

  let smsSender: SmsSender;

  /**
   * @link https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-custom-sender-triggers.html
   */
  return async (event: CustomSMSSenderTriggerEvent | CustomEmailSenderTriggerEvent) => {
    logger.debug({ event }, 'lambda handler triggered');

    // initialize config if not ready
    if (config.state !== AppConfigState.READY) {
      await config.update(process.env);
      const decrypter = new Decrypter(config.keyId);
      const historyRepository = new HistoryRepository(config, awsDdb);
      const policyWasm = await readFile(`${__dirname}/${config.smsSenderPolicyPath}`);
      const policy = new OpaPolicy(policyWasm);
      smsSender = new SmsSender(decrypter, awsSms, historyRepository, policy, config);
    }

    try {
      if (isSmsTriggerEvent(event))
        return await smsSender.send(event.triggerSource, event.request.userAttributes, event.request.code);
    } catch (err: unknown) {
      const data = {
        clientId: event.callerContext.clientId,
        encryptedCode: event.request.code,
        region: event.region,
        triggeredSource: event.triggerSource,
        userPoolId: event.userPoolId,
        userName: event.userName,
        userAttributes: event.request.userAttributes,
      };
      if (err instanceof AppInputError) {
        logger.warn({ customMessageSenderRequest: data, error: err }, err.message);
        return;
      }
      logger.error({ customMessageSenderRequest: data, error: err });
      throw err;
    }
  };
};

export const handler: CustomMessageSenderHandler = init();

import { CustomEmailSenderTriggerHandler, CustomSMSSenderTriggerHandler } from 'aws-lambda';
import { Logger } from 'pino';

export type AppLogger = Logger;

export interface CognitoUserAttributes {
  sub?: string
  email?: string | null
  email_verified?: 'true' | 'false' | null
  phone_number?: string | null
  phone_number_verified?: 'true' | 'false' | null
  [k: string]: any
}

export interface CustomMessageSenderAclRules {
  allowed: {
    emailPatterns: Array<RegExp>
    phoneNumbers: Set<string>
    userAttributes: {
      [k: string]: Set<string>
    }
  }
  denied: {
    countries: Set<string>,
    emailPatterns: Array<RegExp>
    phoneNumbers: Set<string>,
    phoneNumberPatterns: Array<RegExp>,
    userAttributes: {
      [k: string]: Set<string>
    }
  }
}



export interface CustomMessageSenderCountryConfig {
  [key: string]: {
    senderId: string
    shortCode: string
  }
}

export interface CustomMessageSenderLimits {
  smsTimePeriod: number
  smsToPhoneNumber: number
  smsToUserId: number
}

export type CustomMessageSenderHandler = CustomSMSSenderTriggerHandler | CustomEmailSenderTriggerHandler;

export type CustomMessageSenderInitializer = () => CustomMessageSenderHandler;

export interface IDocumentClient<PI, PO, QI, QO> {
  putItem: (input: PI) => Promise<PO>;
  query: (input: QI) => Promise<QO>;
}


export interface SmsMessageTemplates {
  authentication: string
  verification: string
}

export interface EmailMessageTemplateConfig {
  name: string
  subject: string
  message: string
  cta_url?: string
}

export interface EmailMessageTemplateConfigs {
  authentication: EmailMessageTemplateConfig
  forgotPassword: EmailMessageTemplateConfig
}

export interface IMessageClient<MessagePayloadType> {
  send: (payload: MessagePayloadType) => Promise<void>
}

export interface IMessageSender<MessageTriggerType> {
  send: (trigger: MessageTriggerType, userAttributes: CognitoUserAttributes, ecryptedCode?: string | null) => Promise<void>
}

export interface SmsMessagePayload {
  destination: string
  message: string
  messageType: 'Transactional'
  senderId?: string
  shortCode?: string
}

export interface EmailMessagePayload {
  destination: string;
  message: string;
  source: string;
  subject: string;
}

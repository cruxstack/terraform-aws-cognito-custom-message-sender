import { readFile as fsReadFile } from 'fs';

export const isValidRegexString = (value: string): boolean => {
  try {
    new RegExp(value, 'i');
    return true;
  } catch (e) {
    return false;
  }
};

export const readFile = async (path: string): Promise<Buffer> => {
  return new Promise<Buffer>((resolve, reject) => {
    fsReadFile(path, (err, data) => !err ? resolve(data) : reject(err));
  });
};

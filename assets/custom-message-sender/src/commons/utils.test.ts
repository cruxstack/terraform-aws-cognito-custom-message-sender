import { readFile as fsReadFile } from 'fs';
import { isValidRegexString, readFile } from './utils';

jest.mock('fs');

describe('Utility Functions', () => {
  describe('isValidRegexString', () => {
    it('should return true for valid regex', () => {
      expect(isValidRegexString('[a-z]*')).toBe(true);
    });

    it('should return false for invalid regex', () => {
      expect(isValidRegexString('[')).toBe(false);
    });
  });

  describe('readFile', () => {
    it('should resolve with data when read file successfully', async () => {
      const mockData = Buffer.from('mock data');
      (fsReadFile as jest.MockedFunction<typeof fsReadFile>).mockImplementation((path, callback) => callback(null, mockData));

      await expect(readFile('path/to/file')).resolves.toBe(mockData);
    });

    it('should reject with error when fail to read file', async () => {
      const mockError = new Error('mock error');
      (fsReadFile as jest.MockedFunction<typeof fsReadFile>).mockImplementation((path, callback) => callback(mockError, {} as any));

      await expect(readFile('path/to/file')).rejects.toThrow(mockError);
    });
  });
});

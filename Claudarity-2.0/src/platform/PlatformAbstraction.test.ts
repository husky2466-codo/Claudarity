/**
 * Property-Based Tests for Platform Abstraction
 * Tests cross-platform behavior using fast-check
 */

import { describe, it, expect, beforeEach } from 'vitest';
import * as fc from 'fast-check';
import { PlatformAbstractionImpl } from './PlatformAbstraction';
import type { OperatingSystem, ShellType } from './types';
import * as os from 'os';

describe('Platform Abstraction - Property Tests', () => {
  let platform: PlatformAbstractionImpl;

  beforeEach(() => {
    platform = new PlatformAbstractionImpl();
  });

  describe('Property 1: Platform Detection and Configuration', () => {
    it('should detect OS and return one of the supported platforms', () => {
      fc.assert(
        fc.property(fc.constant(null), () => {
          const detectedOS = platform.getOperatingSystem();
          const validOS: OperatingSystem[] = ['windows', 'macos', 'linux'];
          
          expect(validOS).toContain(detectedOS);
        })
      );
    });

    it('should consistently return the same OS on repeated calls', () => {
      fc.assert(
        fc.property(fc.integer({ min: 1, max: 10 }), (iterations) => {
          const firstCall = platform.getOperatingSystem();
          
          for (let i = 0; i < iterations; i++) {
            const subsequentCall = platform.getOperatingSystem();
            expect(subsequentCall).toBe(firstCall);
          }
        })
      );
    });

    it('should configure PowerShell for Windows', () => {
      const detectedOS = platform.getOperatingSystem();
      const shellType = platform.getShellType();
      
      if (detectedOS === 'windows') {
        expect(shellType).toBe('powershell');
      }
    });

    it('should configure bash or zsh for Unix-based systems', () => {
      const detectedOS = platform.getOperatingSystem();
      const shellType = platform.getShellType();
      
      if (detectedOS === 'macos' || detectedOS === 'linux') {
        expect(['bash', 'zsh']).toContain(shellType);
      }
    });

    it('should return valid shell type for any platform', () => {
      fc.assert(
        fc.property(fc.constant(null), () => {
          const shellType = platform.getShellType();
          const validShells: ShellType[] = ['powershell', 'bash', 'zsh'];
          
          expect(validShells).toContain(shellType);
        })
      );
    });

    it('should consistently return the same shell type on repeated calls', () => {
      fc.assert(
        fc.property(fc.integer({ min: 1, max: 10 }), (iterations) => {
          const firstCall = platform.getShellType();
          
          for (let i = 0; i < iterations; i++) {
            const subsequentCall = platform.getShellType();
            expect(subsequentCall).toBe(firstCall);
          }
        })
      );
    });
  });

  describe('Property 2: Path Portability', () => {
    it('should normalize any path to use platform-appropriate separators', () => {
      fc.assert(
        fc.property(
          fc.array(fc.stringOf(fc.constantFrom('a', 'b', 'c', '1', '2', '3'), { minLength: 1, maxLength: 5 }), { minLength: 1, maxLength: 5 }),
          (segments) => {
            // Create path with mixed separators
            const mixedPath = segments.join('/');
            const normalized = platform.normalizePath(mixedPath);
            
            // Should not contain mixed separators
            const hasMixedSeparators = normalized.includes('/') && normalized.includes('\\');
            expect(hasMixedSeparators).toBe(false);
          }
        )
      );
    });

    it('should join path segments using platform-appropriate separator', () => {
      fc.assert(
        fc.property(
          fc.array(fc.stringOf(fc.constantFrom('a', 'b', 'c', '1', '2', '3'), { minLength: 1, maxLength: 5 }), { minLength: 2, maxLength: 5 }),
          (segments) => {
            const joined = platform.joinPath(...segments);
            
            // Result should contain all segments
            segments.forEach(segment => {
              expect(joined).toContain(segment);
            });
            
            // Should use consistent separators
            const detectedOS = platform.getOperatingSystem();
            if (detectedOS === 'windows') {
              // Windows can use both, but typically uses backslash
              expect(joined.includes('/') || joined.includes('\\')).toBe(true);
            } else {
              // Unix uses forward slash
              if (segments.length > 1) {
                expect(joined.includes('/')).toBe(true);
              }
            }
          }
        )
      );
    });

    it('should return platform-appropriate config directory', () => {
      fc.assert(
        fc.property(fc.constant(null), () => {
          const configDir = platform.getConfigDir();
          const detectedOS = platform.getOperatingSystem();
          
          // Should be an absolute path
          expect(configDir.length).toBeGreaterThan(0);
          
          // Should contain platform-appropriate location
          if (detectedOS === 'windows') {
            expect(configDir.toLowerCase()).toMatch(/appdata/);
          } else {
            expect(configDir).toMatch(/\.config|\.kiro/);
          }
        })
      );
    });

    it('should return platform-appropriate data directory', () => {
      fc.assert(
        fc.property(fc.constant(null), () => {
          const dataDir = platform.getDataDir();
          const detectedOS = platform.getOperatingSystem();
          
          // Should be an absolute path
          expect(dataDir.length).toBeGreaterThan(0);
          
          // Should contain platform-appropriate location
          if (detectedOS === 'windows') {
            expect(dataDir.toLowerCase()).toMatch(/appdata/);
          } else {
            expect(dataDir).toMatch(/\.local/);
          }
        })
      );
    });

    it('should handle relative paths without errors', () => {
      fc.assert(
        fc.property(
          fc.array(fc.stringOf(fc.constantFrom('a', 'b', 'c', '.', '1', '2'), { minLength: 1, maxLength: 5 }), { minLength: 1, maxLength: 3 }),
          (segments) => {
            const relativePath = segments.join('/');
            const normalized = platform.normalizePath(relativePath);
            
            expect(normalized).toBeDefined();
            expect(typeof normalized).toBe('string');
          }
        )
      );
    });

    it('should handle environment variable expansion in paths', () => {
      const configDir = platform.getConfigDir();
      const dataDir = platform.getDataDir();
      
      // Both should be absolute paths (not contain unexpanded variables)
      expect(configDir).not.toMatch(/\$\{.*\}/);
      expect(dataDir).not.toMatch(/\$\{.*\}/);
      
      // Should be actual paths on the system
      expect(configDir.length).toBeGreaterThan(0);
      expect(dataDir.length).toBeGreaterThan(0);
    });
  });

  describe('Shell Execution', () => {
    it('should execute simple commands successfully', async () => {
      const detectedOS = platform.getOperatingSystem();
      const command = detectedOS === 'windows' ? 'echo test' : 'echo test';
      
      const result = await platform.executeShellCommand(command);
      
      expect(result).toBeDefined();
      expect(result.stdout).toContain('test');
      expect(result.exitCode).toBe(0);
    });

    it('should handle command failures gracefully', async () => {
      const command = 'nonexistentcommand12345';
      
      const result = await platform.executeShellCommand(command);
      
      expect(result).toBeDefined();
      expect(result.exitCode).not.toBe(0);
    });
  });

  describe('File Operations', () => {
    it('should check file existence correctly', async () => {
      // Test with a file that definitely exists
      const packageJsonPath = platform.joinPath(process.cwd(), 'package.json');
      const exists = await platform.fileExists(packageJsonPath);
      
      expect(exists).toBe(true);
    });

    it('should return false for non-existent files', async () => {
      const nonExistentPath = platform.joinPath(process.cwd(), 'nonexistent-file-12345.txt');
      const exists = await platform.fileExists(nonExistentPath);
      
      expect(exists).toBe(false);
    });
  });
});

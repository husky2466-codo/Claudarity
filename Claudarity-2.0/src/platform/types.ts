/**
 * Platform Abstraction Types
 * Provides cross-platform interfaces for OS detection, path operations, and shell execution
 */

export type OperatingSystem = 'windows' | 'macos' | 'linux';
export type ShellType = 'powershell' | 'bash' | 'zsh';

export interface ShellResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

export interface PlatformAbstraction {
  // OS detection
  getOperatingSystem(): OperatingSystem;
  
  // Path operations
  normalizePath(path: string): string;
  joinPath(...segments: string[]): string;
  getConfigDir(): string;
  getDataDir(): string;
  
  // Shell operations
  getShellType(): ShellType;
  executeShellCommand(command: string): Promise<ShellResult>;
  
  // File operations
  readFile(path: string): Promise<string>;
  writeFile(path: string, content: string): Promise<void>;
  fileExists(path: string): Promise<boolean>;
  createDirectory(path: string): Promise<void>;
}

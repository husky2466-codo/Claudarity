/**
 * Platform Abstraction Implementation
 * Cross-platform support for Windows (PowerShell), macOS (bash/zsh), and Linux (bash)
 */

import * as os from 'os';
import * as path from 'path';
import * as fs from 'fs/promises';
import { exec } from 'child_process';
import { promisify } from 'util';
import type { 
  PlatformAbstraction, 
  OperatingSystem, 
  ShellType, 
  ShellResult 
} from './types';

const execAsync = promisify(exec);

export class PlatformAbstractionImpl implements PlatformAbstraction {
  private cachedOS?: OperatingSystem;
  private cachedShell?: ShellType;

  /**
   * Detect the operating system
   */
  getOperatingSystem(): OperatingSystem {
    if (this.cachedOS) {
      return this.cachedOS;
    }

    const platform = os.platform();
    
    if (platform === 'win32') {
      this.cachedOS = 'windows';
    } else if (platform === 'darwin') {
      this.cachedOS = 'macos';
    } else {
      this.cachedOS = 'linux';
    }
    
    return this.cachedOS;
  }

  /**
   * Normalize path separators for the current platform
   */
  normalizePath(inputPath: string): string {
    return path.normalize(inputPath);
  }

  /**
   * Join path segments using platform-appropriate separator
   */
  joinPath(...segments: string[]): string {
    return path.join(...segments);
  }

  /**
   * Get platform-appropriate configuration directory
   */
  getConfigDir(): string {
    const osType = this.getOperatingSystem();
    const homeDir = os.homedir();

    if (osType === 'windows') {
      // Windows: %APPDATA%
      return process.env.APPDATA || path.join(homeDir, 'AppData', 'Roaming');
    } else {
      // Unix: ~/.config
      return process.env.XDG_CONFIG_HOME || path.join(homeDir, '.config');
    }
  }

  /**
   * Get platform-appropriate data directory
   */
  getDataDir(): string {
    const osType = this.getOperatingSystem();
    const homeDir = os.homedir();

    if (osType === 'windows') {
      // Windows: %LOCALAPPDATA%
      return process.env.LOCALAPPDATA || path.join(homeDir, 'AppData', 'Local');
    } else {
      // Unix: ~/.local/share
      return process.env.XDG_DATA_HOME || path.join(homeDir, '.local', 'share');
    }
  }

  /**
   * Detect the shell type for the current platform
   */
  getShellType(): ShellType {
    if (this.cachedShell) {
      return this.cachedShell;
    }

    const osType = this.getOperatingSystem();
    
    if (osType === 'windows') {
      this.cachedShell = 'powershell';
    } else {
      // Check SHELL environment variable
      const shell = process.env.SHELL || '';
      
      if (shell.includes('zsh')) {
        this.cachedShell = 'zsh';
      } else {
        this.cachedShell = 'bash';
      }
    }
    
    return this.cachedShell;
  }

  /**
   * Execute a shell command on the current platform
   */
  async executeShellCommand(command: string): Promise<ShellResult> {
    const osType = this.getOperatingSystem();
    const shellType = this.getShellType();

    let shellCommand: string;
    
    if (osType === 'windows') {
      // Use PowerShell on Windows
      shellCommand = `powershell.exe -Command "${command.replace(/"/g, '\\"')}"`;
    } else {
      // Use bash or zsh on Unix
      const shell = shellType === 'zsh' ? 'zsh' : 'bash';
      shellCommand = `${shell} -c "${command.replace(/"/g, '\\"')}"`;
    }

    try {
      const { stdout, stderr } = await execAsync(shellCommand);
      return {
        stdout: stdout.trim(),
        stderr: stderr.trim(),
        exitCode: 0
      };
    } catch (error: any) {
      return {
        stdout: error.stdout?.trim() || '',
        stderr: error.stderr?.trim() || error.message,
        exitCode: error.code || 1
      };
    }
  }

  /**
   * Read file contents
   */
  async readFile(filePath: string): Promise<string> {
    return await fs.readFile(filePath, 'utf-8');
  }

  /**
   * Write file contents
   */
  async writeFile(filePath: string, content: string): Promise<void> {
    await fs.writeFile(filePath, content, 'utf-8');
  }

  /**
   * Check if file exists
   */
  async fileExists(filePath: string): Promise<boolean> {
    try {
      await fs.access(filePath);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Create directory (recursive)
   */
  async createDirectory(dirPath: string): Promise<void> {
    await fs.mkdir(dirPath, { recursive: true });
  }
}

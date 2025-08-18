#!/usr/bin/env python3
"""
Disk Space Cleanup Script for NoctisPro DICOM Viewer
This script helps clean up temporary files, logs, and caches to free up disk space.
"""

import os
import shutil
import tempfile
import logging
from datetime import datetime, timedelta
import glob

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def get_directory_size(path):
    """Get the total size of a directory in bytes"""
    total_size = 0
    try:
        for dirpath, dirnames, filenames in os.walk(path):
            for filename in filenames:
                filepath = os.path.join(dirpath, filename)
                try:
                    total_size += os.path.getsize(filepath)
                except (OSError, FileNotFoundError):
                    pass
    except (OSError, FileNotFoundError):
        pass
    return total_size

def format_size(bytes_size):
    """Format bytes to human readable format"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_size < 1024.0:
            return f"{bytes_size:.1f} {unit}"
        bytes_size /= 1024.0
    return f"{bytes_size:.1f} PB"

def clean_temp_directories():
    """Clean temporary directories"""
    temp_dirs = [
        tempfile.gettempdir(),
        '/tmp' if os.path.exists('/tmp') else None,
        'temp',
        'tmp',
    ]
    
    total_cleaned = 0
    
    for temp_dir in temp_dirs:
        if not temp_dir or not os.path.exists(temp_dir):
            continue
            
        logger.info(f"Cleaning temporary directory: {temp_dir}")
        
        try:
            # Clean old files (older than 1 day)
            cutoff_time = datetime.now() - timedelta(days=1)
            
            for root, dirs, files in os.walk(temp_dir):
                for file in files:
                    file_path = os.path.join(root, file)
                    try:
                        if os.path.getmtime(file_path) < cutoff_time.timestamp():
                            file_size = os.path.getsize(file_path)
                            os.remove(file_path)
                            total_cleaned += file_size
                            logger.debug(f"Removed: {file_path}")
                    except (OSError, FileNotFoundError):
                        pass
                        
        except Exception as e:
            logger.error(f"Error cleaning {temp_dir}: {str(e)}")
    
    return total_cleaned

def clean_log_files():
    """Clean old log files"""
    log_patterns = [
        '*.log',
        'logs/*.log',
        'noctis_pro.log*',
        '*.log.*',
    ]
    
    total_cleaned = 0
    cutoff_time = datetime.now() - timedelta(days=7)  # Keep logs for 7 days
    
    for pattern in log_patterns:
        for log_file in glob.glob(pattern):
            try:
                if os.path.getmtime(log_file) < cutoff_time.timestamp():
                    file_size = os.path.getsize(log_file)
                    os.remove(log_file)
                    total_cleaned += file_size
                    logger.info(f"Removed old log file: {log_file}")
            except (OSError, FileNotFoundError):
                pass
    
    return total_cleaned

def clean_cache_directories():
    """Clean cache directories"""
    cache_dirs = [
        '__pycache__',
        '.pytest_cache',
        'staticfiles',
        'media/cache',
    ]
    
    total_cleaned = 0
    
    for cache_dir in cache_dirs:
        if os.path.exists(cache_dir):
            try:
                dir_size = get_directory_size(cache_dir)
                shutil.rmtree(cache_dir)
                total_cleaned += dir_size
                logger.info(f"Removed cache directory: {cache_dir} ({format_size(dir_size)})")
            except Exception as e:
                logger.error(f"Error removing {cache_dir}: {str(e)}")
    
    # Clean Python cache files recursively
    for root, dirs, files in os.walk('.'):
        for dir_name in dirs[:]:  # Use slice to avoid modifying list during iteration
            if dir_name == '__pycache__':
                cache_path = os.path.join(root, dir_name)
                try:
                    dir_size = get_directory_size(cache_path)
                    shutil.rmtree(cache_path)
                    total_cleaned += dir_size
                    logger.debug(f"Removed __pycache__: {cache_path}")
                    dirs.remove(dir_name)
                except Exception as e:
                    logger.error(f"Error removing {cache_path}: {str(e)}")
    
    return total_cleaned

def clean_django_cache():
    """Clean Django-specific cache and session files"""
    total_cleaned = 0
    
    # Clean Django cache files
    django_cache_patterns = [
        'django_cache/*',
        'sessions/*',
        'tmp/django_cache/*',
    ]
    
    for pattern in django_cache_patterns:
        for cache_file in glob.glob(pattern):
            try:
                if os.path.isfile(cache_file):
                    file_size = os.path.getsize(cache_file)
                    os.remove(cache_file)
                    total_cleaned += file_size
                elif os.path.isdir(cache_file):
                    dir_size = get_directory_size(cache_file)
                    shutil.rmtree(cache_file)
                    total_cleaned += dir_size
            except (OSError, FileNotFoundError):
                pass
    
    return total_cleaned

def optimize_database():
    """Optimize SQLite database if it exists"""
    db_file = 'db.sqlite3'
    if os.path.exists(db_file):
        try:
            original_size = os.path.getsize(db_file)
            
            # Create a backup
            backup_file = f"{db_file}.backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            shutil.copy2(db_file, backup_file)
            logger.info(f"Database backup created: {backup_file}")
            
            # Vacuum the database (requires sqlite3 command line tool)
            import sqlite3
            conn = sqlite3.connect(db_file)
            conn.execute('VACUUM;')
            conn.close()
            
            new_size = os.path.getsize(db_file)
            space_saved = original_size - new_size
            
            if space_saved > 0:
                logger.info(f"Database optimized: {format_size(space_saved)} saved")
                return space_saved
            else:
                logger.info("Database was already optimized")
                return 0
                
        except Exception as e:
            logger.error(f"Error optimizing database: {str(e)}")
            return 0
    
    return 0

def main():
    """Main cleanup function"""
    logger.info("Starting disk space cleanup...")
    
    total_cleaned = 0
    
    # Clean temporary directories
    logger.info("Cleaning temporary directories...")
    total_cleaned += clean_temp_directories()
    
    # Clean log files
    logger.info("Cleaning old log files...")
    total_cleaned += clean_log_files()
    
    # Clean cache directories
    logger.info("Cleaning cache directories...")
    total_cleaned += clean_cache_directories()
    
    # Clean Django cache
    logger.info("Cleaning Django cache...")
    total_cleaned += clean_django_cache()
    
    # Optimize database
    logger.info("Optimizing database...")
    total_cleaned += optimize_database()
    
    logger.info(f"Cleanup completed! Total space freed: {format_size(total_cleaned)}")
    
    # Show current disk usage
    try:
        import shutil
        total, used, free = shutil.disk_usage('.')
        logger.info(f"Current disk usage: {format_size(used)}/{format_size(total)} ({100*used/total:.1f}%)")
        logger.info(f"Free space: {format_size(free)}")
    except Exception:
        pass

if __name__ == '__main__':
    main()
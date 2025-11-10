#if !__has_feature(objc_arc)
#error "ARC is required for this project."
#endif

#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
// This could be written in strict Objective-C, but this works fine
NSString* hashFile(const char *target)
{
    FILE *file = fopen(target, "rb");
    if (file == NULL)
        return nil;

    // Read files in 128 MiB chunks
    // This will mean 1 GiB will be used with 8 threads at one time
    const size_t chunkSize = 134217728;
    size_t bytesRead;
    
    char *buffer = malloc(chunkSize);
    if (buffer == NULL) {
        fclose(file);
        return nil;
    }
    
    CC_MD5_CTX context;
    CC_MD5_Init(&context);
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    char digestString[(CC_MD5_DIGEST_LENGTH*2) + 1];
    digestString[CC_MD5_DIGEST_LENGTH*2] = '\0';
    
    while ((bytesRead = fread(buffer, 1, chunkSize, file)) > 0) {
        CC_MD5_Update(&context, buffer, bytesRead);
    }
    
    CC_MD5_Final(digest, &context);
    
    fclose(file);
    free(buffer);
    
    for (NSUInteger i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        unsigned char tmp = digest[i] >> 4;
        digestString[i*2] = (tmp >= 0xA) ? tmp+87 : tmp+48;

        tmp = digest[i] & 0xF;
        digestString[(i*2) + 1] = (tmp >= 0xA) ? tmp+87 : tmp+48;
    }

    return [NSString stringWithUTF8String:digestString];
}
#pragma clang diagnostic pop

BOOL renameFile(NSString *source)
{
    NSString *extension = [source pathExtension];
    NSString *targetDir = [source stringByDeletingLastPathComponent];

    NSString *hash = hashFile([source fileSystemRepresentation]);
    if (hash == nil)
        return NO;

    NSString *target = [[targetDir stringByAppendingPathComponent:hash] stringByAppendingPathExtension:extension];

    BOOL success = YES;

    if (![source isEqualToString:target])
        success = [[NSFileManager defaultManager] moveItemAtPath:source toPath:target error:nil];

    return success;
}

NSArray<NSString *> *findFiles(NSString *parentDirectory)
{
    NSMutableArray<NSString *> *fileList = [[NSMutableArray alloc] init];
    NSString *file;
    
    NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:parentDirectory];
    
    while (file = [dirEnum nextObject]) {
        file = [parentDirectory stringByAppendingPathComponent:file];
        
        if ([file hasPrefix:@"."])
            continue;

        struct stat fileStat;

        if (lstat([file fileSystemRepresentation], &fileStat) < 0)
            continue;

        if ((!S_ISREG(fileStat.st_mode)) || (fileStat.st_flags & UF_HIDDEN))
            continue;

        [fileList addObject:file];
    }
    
    return [fileList copy];
}

int main(int argc, const char *argv[])
{
    if (argc < 2) {
        NSLog(@"Invalid argument count.");
        printf("Usage:\n");
        printf("  hasher <directory> [<conflicts>]\n\n");
        printf("For more information, see hasher(1).\n");
        return 1;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    
    NSString *directory = [fileManager stringWithFileSystemRepresentation:argv[1] length:strlen(argv[1])];
    if (![fileManager fileExistsAtPath:directory isDirectory:&isDir] || !isDir) {
        NSLog(@"Invalid target directory path.");
        return 1;
    }
    
    NSString *conflictFile = (argc < 3) ? nil : [fileManager stringWithFileSystemRepresentation:argv[2] length:strlen(argv[2])];
    if (conflictFile != nil && (![fileManager fileExistsAtPath:conflictFile isDirectory:&isDir] || isDir)) {
        NSLog(@"Invalid conflict file path.");
        return 1;
    }
    
    NSArray<NSString *> *files = findFiles(directory);
    
    // Do everything serially if there is no conflict file
    if (conflictFile == nil) {
        BOOL previousSuccess = YES;

        for (NSString *file in files) {
            if (!(previousSuccess = renameFile(file)))
                break;
        }

        if (!previousSuccess) {
            NSLog(([files count] == 1) ? @"Possible conflict when moving file." : @"Possible conflict when moving files.");
            return 1;
        } else {
            return 0;
        }
    }
    
    // Open conflict file
    NSOutputStream *conflictFileStream = [[NSOutputStream alloc] initToFileAtPath:conflictFile append:YES];
    [conflictFileStream open];
    
    dispatch_queue_t serialQueue = dispatch_queue_create("serial_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t parallelQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    dispatch_apply([files count], parallelQueue, ^(size_t iteration) {
        if (!renameFile([files objectAtIndex:iteration]))
            dispatch_sync(serialQueue, ^{
                if ([conflictFileStream hasSpaceAvailable]) {
                    const char *cFileName = [[[files objectAtIndex:iteration] stringByAppendingString:@"\n"] UTF8String];
                    [conflictFileStream write:(const uint8_t *)cFileName maxLength:strlen(cFileName)];
                }
            });
    });
    
    [conflictFileStream close];

    return 0;
}

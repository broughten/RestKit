//
//  RKManagedObjectThreadSafeInvocation.m
//  RestKit
//
//  Created by Blake Watters on 5/12/11.
//  Copyright (c) 2009-2012 RestKit. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "RKManagedObjectThreadSafeInvocation.h"

@implementation RKManagedObjectThreadSafeInvocation

@synthesize objectStore = _objectStore;

+ (RKManagedObjectThreadSafeInvocation *)invocationWithMethodSignature:(NSMethodSignature *)methodSignature
{
    return (RKManagedObjectThreadSafeInvocation *)[super invocationWithMethodSignature:methodSignature];
}

- (void)setManagedObjectKeyPaths:(NSSet *)keyPaths forArgument:(NSInteger)index
{
    if (nil == _argumentKeyPaths) {
        _argumentKeyPaths = [[NSMutableDictionary alloc] init];
    }

    NSNumber *argumentIndex = [NSNumber numberWithInteger:index];
    [_argumentKeyPaths setObject:keyPaths forKey:argumentIndex];
}

- (void)setValue:(id)value forKeyPathOrKey:(NSString *)keyPath object:(id)object
{
    NSLog(@"HI JC!!! setting value %@ for keyPath %@", value, keyPath);
    [object setValue:value forKeyPath:keyPath];

    id testValue = [object valueForKeyPath:keyPath];
    if (![value isEqual:testValue]) {
        NSLog(@"HI JC!!! here's a weird place to ever get. did we get in here?");
        [object setValue:value forKey:keyPath];
        testValue = [object valueForKeyPath:keyPath];

        NSAssert([value isEqual:testValue], @"Could not set value");
    }
}

- (void)serializeManagedObjectsForArgument:(id)argument withKeyPaths:(NSSet *)keyPaths
{
    NSLog(@"HI JC!!! called serialize managed objects for argument %@", argument);
    
    for (NSString *keyPath in keyPaths) {
        id value = [argument valueForKeyPath:keyPath];
        if ([value isKindOfClass:[NSManagedObject class]]) {
            NSManagedObjectID *objectID = [(NSManagedObject *)value objectID];
            NSLog(@"HI JC!!! serializing objects, and we have an ns managed object with id: %@", objectID);
            [self setValue:objectID forKeyPathOrKey:keyPath object:argument];
        } else if ([value respondsToSelector:@selector(allObjects)]) {
            id collection = [[[[[value class] alloc] init] autorelease] mutableCopy];
            for (id subObject in value) {
                if ([subObject isKindOfClass:[NSManagedObject class]]) {
                    [collection addObject:[(NSManagedObject *)subObject objectID]];
                } else {
                    [collection addObject:subObject];
                }
            }

            [self setValue:collection forKeyPathOrKey:keyPath object:argument];
            [collection release];
        }
    }
}

- (void)deserializeManagedObjectIDsForArgument:(id)argument withKeyPaths:(NSSet *)keyPaths
{
    for (NSString *keyPath in keyPaths) {
        id value = [argument valueForKeyPath:keyPath];
        if ([value isKindOfClass:[NSManagedObjectID class]]) {
            NSAssert(self.objectStore, @"Object store cannot be nil");
            NSManagedObject *managedObject = [self.objectStore objectWithID:(NSManagedObjectID *)value];
            NSAssert(managedObject, @"Expected managed object for ID %@, got nil", value);
            [self setValue:managedObject forKeyPathOrKey:keyPath object:argument];
        } else if ([value respondsToSelector:@selector(allObjects)]) {
            id collection = [[[[[value class] alloc] init] autorelease] mutableCopy];
            for (id subObject in value) {
                if ([subObject isKindOfClass:[NSManagedObjectID class]]) {
                    NSAssert(self.objectStore, @"Object store cannot be nil");
                    NSManagedObject *managedObject = [self.objectStore objectWithID:(NSManagedObjectID *)subObject];
                    [collection addObject:managedObject];
                } else {
                    [collection addObject:subObject];
                }
            }

            [self setValue:collection forKeyPathOrKey:keyPath object:argument];
            [collection release];
        }
    }
}
- (void)serializeManagedObjects
{
    NSLog(@"HI JC!!! called invoke serialize managed objects");
    
    for (NSNumber *argumentIndex in _argumentKeyPaths) {
        NSSet *managedKeyPaths = [_argumentKeyPaths objectForKey:argumentIndex];
        id argument = nil;
        [self getArgument:&argument atIndex:[argumentIndex intValue]];
        if (argument) {
            [self serializeManagedObjectsForArgument:argument withKeyPaths:managedKeyPaths];
        }
    }
}

- (void)deserializeManagedObjects
{
    for (NSNumber *argumentIndex in _argumentKeyPaths) {
        NSSet *managedKeyPaths = [_argumentKeyPaths objectForKey:argumentIndex];
        id argument = nil;
        [self getArgument:&argument atIndex:[argumentIndex intValue]];
        if (argument) {
            [self deserializeManagedObjectIDsForArgument:argument withKeyPaths:managedKeyPaths];
        }
    }
}

- (void)performInvocationOnMainThread
{
    NSLog(@"HI JC!!! performing invokation on man thread");
    [self deserializeManagedObjects];
    [self invoke];
}

- (void)invokeOnMainThread
{
    NSLog(@"HI JC!!! called invoke on main thread");
    [self retain];
    [self serializeManagedObjects];
    [self performSelectorOnMainThread:@selector(performInvocationOnMainThread) withObject:nil waitUntilDone:YES];
    [self release];
}

- (void)dealloc
{
    [_argumentKeyPaths release];
    [_objectStore release];
    [super dealloc];
}

@end

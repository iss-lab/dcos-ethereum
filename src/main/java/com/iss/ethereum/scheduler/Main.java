// MIT License
//
// Copyright (c) 2018 Institutional Shareholder Services. All other rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

package com.iss.ethereum.scheduler;

import com.mesosphere.sdk.curator.CuratorPersister;
import com.mesosphere.sdk.framework.EnvStore;
import com.mesosphere.sdk.framework.FrameworkConfig;
import com.mesosphere.sdk.scheduler.DefaultScheduler;
import com.mesosphere.sdk.scheduler.SchedulerBuilder;
import com.mesosphere.sdk.scheduler.SchedulerConfig;
import com.mesosphere.sdk.scheduler.SchedulerRunner;
import com.mesosphere.sdk.specification.DefaultServiceSpec;
import com.mesosphere.sdk.specification.ServiceSpec;
import com.mesosphere.sdk.specification.yaml.RawServiceSpec;
import com.mesosphere.sdk.storage.Persister;
import com.mesosphere.sdk.storage.PersisterCache;

import java.io.File;
import java.util.Arrays;

/**
 * Main entry point for the Scheduler.
 */
public final class Main {

  private Main() {}

  public static void main(String[] args) throws Exception {
    if (args.length != 1) {
      throw new IllegalArgumentException(
        "Expected one file argument, got: " + Arrays.toString(args));
    }

    // Read config from provided file
    File yamlFile = new File(args[0]);

    final EnvStore envStore = EnvStore.fromEnv();
    final SchedulerConfig schedulerConfig = SchedulerConfig.fromEnvStore(envStore);

    RawServiceSpec rawServiceSpec = RawServiceSpec.newBuilder(yamlFile).build();
    ServiceSpec serviceSpec = DefaultServiceSpec
        .newGenerator(rawServiceSpec, schedulerConfig, yamlFile.getParentFile())
        .build();
    FrameworkConfig frameworkConfig = FrameworkConfig.fromServiceSpec(serviceSpec);
    Persister persister = CuratorPersister
        .newBuilder(frameworkConfig.getFrameworkName(), frameworkConfig.getZookeeperHostPort())
        .build();
    if (schedulerConfig.isStateCacheEnabled()) {
      persister = new PersisterCache(persister, schedulerConfig);
    }
    SchedulerBuilder builder = DefaultScheduler
        .newBuilder(serviceSpec, schedulerConfig, persister)
        .setPlansFrom(rawServiceSpec);
    SchedulerRunner
        .fromSchedulerBuilder(builder)
        .run();
  }
}

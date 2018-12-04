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

import com.mesosphere.sdk.scheduler.plan.Status;
import com.mesosphere.sdk.testing.Expect;
import com.mesosphere.sdk.testing.Send;
import com.mesosphere.sdk.testing.ServiceTestResult;
import com.mesosphere.sdk.testing.ServiceTestRunner;
import com.mesosphere.sdk.testing.SimulationTick;
import org.apache.mesos.Protos;
import org.junit.After;
import org.junit.Test;
import org.mockito.Mockito;

import java.util.ArrayList;
import java.util.Collection;

public class ServiceTest {

  private static final String VALID_HOSTNAME_CONSTRAINT = "[[\"hostname\", \"UNIQUE\"]]";

  private static final String INVALID_HOSTNAME_CONSTRAINT = "[[\\\"hostname\\\", \"UNIQUE\"]]";

  @After
  public void afterTest() {
    Mockito.validateMockitoUsage();
  }

  @Test
  public void testSpec() throws Exception {
    new ServiceTestRunner().run(getDefaultDeploymentTicks());
  }

  @Test
  public void testValidPlacementConstraint() throws Exception {
    new ServiceTestRunner()
        .setSchedulerEnv("BOOT_NODE_PLACEMENT", VALID_HOSTNAME_CONSTRAINT)
        .run(getDefaultDeploymentTicks());
  }

  @Test(expected = IllegalStateException.class)
  public void testInvalidPlacementConstraint() throws Exception {
    new ServiceTestRunner()
        .setSchedulerEnv("BOOT_NODE_PLACEMENT", INVALID_HOSTNAME_CONSTRAINT)
        .run(getDefaultDeploymentTicks());
  }

  @Test
  public void testSwitchToInvalidPlacementConstraint() throws Exception {
    ServiceTestResult initial = new ServiceTestRunner()
        .setSchedulerEnv("BOOT_NODE_PLACEMENT", VALID_HOSTNAME_CONSTRAINT)
        .run(getDefaultDeploymentTicks());

    Collection<SimulationTick> ticks = new ArrayList<>();
    ticks.add(Send.register());
    ticks.add(Expect.planStatus("deploy", Status.ERROR));

    new ServiceTestRunner()
        .setState(initial)
        .setSchedulerEnv("BOOT_NODE_PLACEMENT", INVALID_HOSTNAME_CONSTRAINT)
        .run(ticks);
  }

  private Collection<SimulationTick> getDefaultDeploymentTicks() throws Exception {
    Collection<SimulationTick> ticks = new ArrayList<>();

    ticks.add(Send.register());

    ticks.add(Expect.reconciledImplicitly());

    // "node" task fails to launch on first attempt, without having entered RUNNING.
    ticks.add(Send.offerBuilder("boot").build());
    ticks.add(Expect.launchedTasks("boot-0-node"));
    ticks.add(Send.taskStatus("boot-0-node", Protos.TaskState.TASK_ERROR).build());
    // Offers are revived following the failure:
    ticks.add(Expect.revivedOffers(1));

    // Because the task has now been "pinned", a different offer which would fit the task is declined:
    ticks.add(Send.offerBuilder("boot").build());
    ticks.add(Expect.declinedLastOffer());

    // It accepts the offer with the correct resource ids:
    ticks.add(Send.offerBuilder("boot").setPodIndexToReoffer(0).build());
    ticks.add(Expect.launchedTasks("boot-0-node"));
    ticks.add(Send.taskStatus("boot-0-node", Protos.TaskState.TASK_RUNNING).build());

    // With the pod now running, the scheduler now ignores the same resources if they're reoffered:
    ticks.add(Send.offerBuilder("boot").setPodIndexToReoffer(0).build());
    ticks.add(Expect.declinedLastOffer());

    // ticks.add(Expect.allPlansComplete());

    return ticks;
  }


}

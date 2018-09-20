/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    Node.NeighborTimer -> NeighborTimerC;
    //list of nodes previously visited
    components new ListC(pack, 20) as nodesVisitedC;
    Node.nodesVisited -> nodesVisitedC;

    components new ListC(neighbor*, 20) as listOfNeighborsC;
    Node.ListOfNeighborsC -> ListOfNeighbors;

    components new PoolC(neighbor, 64) as NeighborPoolC;
    Node.NeighborPool -> NeighborPoolC;

    components RandomC as Random;
    Node.Random -> Random;

    components new TimerMilliC() as NeighborTimerC;
    Node.NeighborTimer -> NeighborTimerC;


}

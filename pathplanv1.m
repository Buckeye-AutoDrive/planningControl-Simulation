clear all
close all
clc

load('Part_of_MCity.mat');
load('xpts.mat');
load('ypts.mat');
load('Mcity_Digraph.mat');
load('edgesptsv1.mat');

scenario = drivingScenario;
roadNetwork(scenario,'OpenDRIVE','minimcity.xodr');



plot(scenario);
hold on
p=plot(G,'XData',x,'YData',y,'EdgeColor','r','LineWidth',2,'MarkerSize',6,'NodeColor','r','ArrowSize',10);
ylim([-100 150])
xlim([-100 80])
view([0 90])

% Finding nearest edge and path selection
[x1,y1] = getpts;

for j = 1:2 % 1 = starting point, 2 = destination
    for q = 1:numnodes(G)%numedges(G)
        NodeDist(q,j) = norm([x1(j)-x(q) y1(j)-y(q)]);
    end
end
[val,indx] = sort(NodeDist,'ascend');
for q = 1:length(indx)
    if any(eq(G.Edges.EndNodes(:,1),indx(q,1)))
        StartPoint = indx(q,1);
        break
    end
end
for q = 1:length(indx)
    if any(eq(G.Edges.EndNodes(:,2),indx(q,2)))
        EndPoint = indx(q,2);
        break
    end
end

[OptPath,len] = shortestpath(G,StartPoint,EndPoint,'Method', 'positive');

highlight(p,OptPath,'EdgeColor','blue','LineWidth',4,'ArrowSize',10);
plot(x1,y1,'x','color','g','MarkerSize',20,'linewidth',8);
ylim([-100 150])
xlim([-100 80])
pause(1)

delete(p)

% waypoint concatanation
xp=[];
yp=[];
for j=1:length(OptPath)-1
    source=OptPath(j);
    dest=OptPath(j+1);

    for i=1:length(edges)
        if edges(i).source == source & edges(i).target==dest

            %concatination
           xpoints=transpose(edges(i).x);
           ypoints=transpose(edges(i).y);

           xp=[xp xpoints];
           yp=[yp ypoints];
        end   
    end    
end 


hold on

plot(xp,yp,'-o','color','b','linewidth',2);
plot(x1,y1,'x','color','g','MarkerSize',20,'linewidth',8);
ylim([-100 150])
xlim([-100 80])
text(x1(1)-5,y1(1)-5,'Start','Color','red','FontSize',20);
text(x1(2)-10,y1(2)+7,'Finish','Color','red','FontSize',20);
view([0 90])
hold off


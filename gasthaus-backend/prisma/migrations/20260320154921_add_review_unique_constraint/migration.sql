/*
  Warnings:

  - A unique constraint covering the columns `[customerId,menuItemId,orderId]` on the table `Review` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateIndex
CREATE UNIQUE INDEX "Review_customerId_menuItemId_orderId_key" ON "Review"("customerId", "menuItemId", "orderId");

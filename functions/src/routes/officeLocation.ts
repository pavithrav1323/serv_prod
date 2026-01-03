import { Router } from 'express';
import * as officeLocationController from '../controllers/officeLocationController';

const router = Router();

/**
 * Mount this at `/api/office`, e.g.:
 *   app.use('/api/office', officeLocationRoutes);
 *
 * Endpoints:
 *   POST   /api/office/add
 *   GET    /api/office/locations
 *   DELETE /api/office/delete/:docId
 */

router.post('/add', officeLocationController.addOrUpdateLocation);
router.get('/locations', officeLocationController.getAllLocations);
router.delete('/delete/:docId', officeLocationController.deleteLocation);

export default router;

import { Router } from 'express';
import * as companyController from '../controllers/companyController';
import { authMiddleware } from '../middlewares/authMiddleware';
import multer, { FileFilterCallback } from 'multer';
import { Request } from 'express';

const router = Router();

// Debug middleware to log requests hitting this router (kept)
router.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

/**
 * NOTE:
 * Do NOT prefix with /api or /company here.
 * index.ts mounts this router at `/api/company`, so final paths are:
 *   GET  /api/company/profile/check
 *   GET  /api/company/profile
 *   POST /api/company/profile
 */

/**
 * @swagger
 * /api/company/profile/check:
 *   get:
 *     summary: Check if company profile exists for the authenticated admin
 *     tags: [Company]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Successfully checked company profile status
 *       400:
 *         description: Missing or invalid parameters
 *       401:
 *         description: Unauthorized - Invalid or missing token
 *       500:
 *         description: Internal server error
 */
router.get('/profile/check', authMiddleware, companyController.checkCompanyProfile);

// Configure multer for file uploads (logo is optional)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req: Request, file: Express.Multer.File, cb: FileFilterCallback) => {
    // Accept images only
    if (!file.originalname.match(/\.(jpg|jpeg|png|gif)$/i)) {
      return cb(new Error('Only image files are allowed!'));
    }
    cb(null, true);
  },
});

/**
 * @swagger
 * /api/company/profile:
 *   post:
 *     summary: Save or update company profile
 *     tags: [Company]
 *     consumes:
 *       - multipart/form-data
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               logo:
 *                 type: string
 *                 format: binary
 *               companyName:
 *                 type: string
 *               email:
 *                 type: string
 *               phone:
 *                 type: string
 *               website:
 *                 type: string
 *               adminName:
 *                 type: string
 *               designation:
 *                 type: string
 *     responses:
 *       200:
 *         description: Company profile saved successfully
 *       400:
 *         description: Missing required fields
 *       500:
 *         description: Internal server error
 */
router.post('/profile', authMiddleware, upload.single('logo'), companyController.saveCompanyProfile);

/**
 * @swagger
 * /api/company/profile:
 *   get:
 *     summary: Get company profile
 *     tags: [Company]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Company profile retrieved successfully
 *       404:
 *         description: Company profile not found
 *       500:
 *         description: Internal server error
 */
router.get('/profile', authMiddleware, companyController.getCompanyProfile);

export default router;

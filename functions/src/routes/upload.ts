import { Router } from 'express';
import { uploadSingle, uploadMultiple } from '../middlewares/uploadMiddleware';
import { 
  uploadSingleFile, 
  uploadMultipleFiles, 
  deleteUploadedFile 
} from '../controllers/uploadController';
import { authMiddleware } from '../middlewares/authMiddleware';

const router = Router();

// Protected routes (require authentication)
router.use(authMiddleware);

// Upload single file
router.post('/single', uploadSingle('file'), uploadSingleFile);

// Upload multiple files (max 5)
router.post('/multiple', uploadMultiple('files', 5), uploadMultipleFiles);

// Delete a file
router.delete('/:filePath', deleteUploadedFile);

export default router;

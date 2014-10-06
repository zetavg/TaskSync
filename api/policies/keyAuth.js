/**
 * keyAuth
 *
 * @module      :: Policy
 * @description :: Simple policy to allow using key
 *                 Assumes that your send the specified key though parameter
 *
 */
module.exports = function(req, res, next) {

  // User is allowed, proceed to the next policy,
  // or if this is the last policy, the controller
  if (req.param('key') == sails.appKey) {
    return next();
  }

  // User is not allowed
  // (default res.forbidden() behavior can be overridden in `config/403.js`)
  return res.status(403).send({error: 'Bad key.', status: 'error'});
};
